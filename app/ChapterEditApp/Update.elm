module ChapterEditApp.Update exposing (..)

import Http
import Json.Encode
import Browser.Navigation as Nav
import Task
import Process
import Time

import Core.Routes exposing (Route(..))
import Common.Models exposing (Banner, Narration, Chapter, FileSet, FileUploadError, FileUploadSuccess, MediaType(..), errorBanner, successBanner, bannerForHttpError, mediaTypeString, updateNarrationFiles, toUtcString)
import Common.Ports exposing (initEditor, renderText, openFileInput, uploadFile, playPauseAudioPreview, setCustomNarrationStyles)
import ChapterEditApp.Api
import ChapterEditApp.Messages exposing (..)
import ChapterEditApp.Models exposing (..)
import ChapterEditApp.Ports exposing (updateParticipants)


initNewChapterCmd : Narration -> Cmd Msg
initNewChapterCmd narration =
  Task.perform (\_ -> InitNewChapter narration) (Task.succeed 1)


updateChapter : Chapter -> FileUploadSuccess -> Chapter
updateChapter chapter uploadResponse =
  case uploadResponse.type_ of
    "audio" ->
      { chapter | audio = Just uploadResponse.name }

    "backgroundImages" ->
      { chapter | backgroundImage = Just uploadResponse.name }

    _ ->
      chapter


urlUpdate : Route -> Model -> ( Model, Cmd Msg )
urlUpdate route model =
  case route of
    ChapterEditNarratorPage chapterId ->
      ( { model | narrationChapterSearchTerm = ""
                , narrationChapterSearchResults = Nothing
                , chapterModified = False
                , notesModified = False
        }
      , Cmd.batch
        [ ChapterEditApp.Api.fetchChapterInfo chapterId
        , ChapterEditApp.Api.fetchLastReactions chapterId
        , Task.perform ReceiveCurrentPosixTime Time.now
        ]
      )

    CreateChapterPage narrationId ->
      ( { model | chapter = Nothing
                , lastChapters = Nothing
                , narrationChapterSearchTerm = ""
                , narrationChapterSearchResults = Nothing
                , chapterModified = False
                , notesModified = False
        }
      , Cmd.batch
        [ ChapterEditApp.Api.fetchNarrationInfo narrationId
        , ChapterEditApp.Api.fetchNarrationLastReactions narrationId
        , Task.perform ReceiveCurrentPosixTime Time.now
        ]
      )

    _ ->
      ( model, Cmd.none )


showFlashMessage : FlashMessageType -> Maybe Banner -> Cmd Msg
showFlashMessage flashType maybeBanner =
  Cmd.batch
    [ Process.sleep 0
      |> Task.perform (\_ -> SetFlashMessage flashType maybeBanner)
    , Process.sleep 2000
      |> Task.perform (\_ -> RemoveFlashMessage flashType)
    ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    NoOp ->
      ( model, Cmd.none )

    NavigateTo url ->
      ( model, Nav.pushUrl model.key url )

    ReceiveCurrentPosixTime posixTime ->
      ( { model | nowMilliseconds = Time.posixToMillis posixTime }
      , Cmd.none
      )

    SetFlashMessage flashType maybeBanner ->
      ( if flashType == ChapterSaveFlash then
          { model | flash = maybeBanner }
        else
          { model | notesFlash = maybeBanner }
      , Cmd.none
      )

    RemoveFlashMessage flashType ->
      ( if flashType == ChapterSaveFlash then
          { model | flash = Nothing }
        else
          { model | notesFlash = Nothing }
      , Cmd.none
      )

    ChapterFetchResult (Err error) ->
      ( { model | banner = bannerForHttpError error }
      , Cmd.none
      )

    ChapterFetchResult (Ok chapter) ->
      ( { model | chapter = Just chapter }
      , ChapterEditApp.Api.fetchNarrationInfo chapter.narrationId
      )

    InitNewChapter narration ->
      ( { model | chapter = Just (newEmptyChapter narration)
                , banner = Nothing
                , flash = Nothing
        }
      , initEditor { elemId = "editor-container"
                   , narrationId = narration.id
                   , narrationImages = narration.files.images
                   , chapterParticipants = narration.characters
                   , text = Json.Encode.null
                   , editorType = "chapter"
                   , updatePortName = "editorContentChanged"
                   }
      )

    NarrationFetchResult (Err error) ->
      ( { model | banner = bannerForHttpError error }
      , Cmd.none
      )

    NarrationFetchResult (Ok narration) ->
      let
        action =
          case model.chapter of
            Nothing ->
              initNewChapterCmd narration

            Just ch ->
              initEditor { elemId = "editor-container"
                         , narrationId = narration.id
                         , narrationImages = narration.files.images
                         , chapterParticipants = ch.participants
                         , text = ch.text
                         , editorType = "chapter"
                         , updatePortName = "editorContentChanged"
                         }
      in
        ( { model | narration = Just narration }
        , Cmd.batch [ action
                    , setCustomNarrationStyles narration.id
                    ]
        )

    NarrationLastReactionsFetchResult (Err error) ->
      ( { model | banner = bannerForHttpError error }
      , Cmd.none
      )

    NarrationLastReactionsFetchResult (Ok lastReactions) ->
      let
        narrationId = case model.narration of
                        Just narr -> narr.id
                        Nothing -> -1
      in
        ( { model | lastChapters = Just lastReactions.lastChapters }
        , Cmd.batch <| List.append
            (List.map
              (\c -> renderText { elemId = "chapter-text-" ++ (String.fromInt c.id)
                                , text = c.text
                                , proseMirrorType = "chapter"
                                })
              lastReactions.lastChapters)
            [ setCustomNarrationStyles narrationId
            ]
        )

    LastReactionsFetchResult (Err error) ->
      ( { model | banner = bannerForHttpError error }
      , Cmd.none
      )

    LastReactionsFetchResult (Ok lastReactions) ->
      ( { model | lastChapters = Just lastReactions.lastChapters }
      , Cmd.batch <|
          (List.map
             (\c -> renderText { elemId = "chapter-text-" ++ (String.fromInt c.id)
                               , text = c.text
                               , proseMirrorType = "chapter"
                               })
             lastReactions.lastChapters)
      )

    UpdateChapterTitle newTitle ->
      case model.chapter of
        Just chapter ->
          let
            newChapter =
              { chapter | title = newTitle }
          in
            ( { model | chapter = Just newChapter
                      , banner = Nothing
                      , chapterModified = True
              }
            , Cmd.none
            )

        Nothing ->
          ( model, Cmd.none )

    UpdateEditorContent newText ->
      case model.chapter of
        Just chapter ->
          let
            updatedChapter = { chapter | text = newText }
          in
            ( { model | chapter = Just updatedChapter
                      , banner = Nothing
                      , chapterModified = True
              }
            , Cmd.none
            )

        Nothing ->
          ( model, Cmd.none )

    AddParticipant character ->
      case model.chapter of
        Just chapter ->
          let
            participantsWithoutCharacter =
              List.filter (\p -> p /= character) chapter.participants

            participantsWithCharacter =
              character :: participantsWithoutCharacter

            chapterWithCharacter =
              { chapter | participants = participantsWithCharacter }
          in
            ( { model | chapter = Just chapterWithCharacter
                      , chapterModified = True
              }
            , updateParticipants { editor = "editor-container"
                                 , participantList = participantsWithCharacter
                                 }
            )

        Nothing ->
          ( model, Cmd.none )

    RemoveParticipant character ->
      case model.chapter of
        Just chapter ->
          let
            updatedParticipantList =
              List.filter (\p -> p /= character) chapter.participants

            updatedChapter =
              { chapter | participants = updatedParticipantList }
          in
            ( { model | chapter = Just updatedChapter
                      , chapterModified = True
              }
            , updateParticipants { editor = "editor-container"
                                 , participantList = updatedParticipantList
                                 }
            )

        Nothing ->
          ( model, Cmd.none )

    UpdateSelectedBackgroundImage imageUrl ->
      case model.chapter of
        Just chapter ->
          let
            newBgImage = if imageUrl == "" then Nothing else Just imageUrl

            updatedChapter = { chapter | backgroundImage = newBgImage }
          in
            ( { model | chapter = Just updatedChapter
                      , chapterModified = True
              }
            , Cmd.none
            )

        Nothing ->
          ( model, Cmd.none )

    UpdateSelectedAudio audioUrl ->
      case model.chapter of
        Just chapter ->
          let
            newAudio = if audioUrl == "" then Nothing else Just audioUrl

            updatedChapter = { chapter | audio = newAudio }
          in
            ( { model | chapter = Just updatedChapter
                      , chapterModified = True
              }
            , Cmd.none
            )

        Nothing ->
          ( model, Cmd.none )

    PlayPauseAudioPreview ->
      ( model, playPauseAudioPreview "audio-preview" )

    ToggleLastReactions ->
      let
        newShowLastReactions = not model.showLastReactions
      in
        ( { model | showLastReactions = newShowLastReactions }
        , Cmd.none
        )

    OpenMediaFileSelector fileInputId ->
      ( model, openFileInput fileInputId )

    AddMediaFile mediaType fileInputId ->
      case model.chapter of
        Just chapter ->
          let
            modelWithUploadFlag =
              case mediaType of
                Audio -> { model | uploadingAudio = True }
                BackgroundImage -> { model | uploadingBackgroundImage = True }
                Font -> { model | uploadingFont = True }
                Image -> model
          in
            ( modelWithUploadFlag
            , uploadFile { type_ = mediaTypeString mediaType
                         , portType = "chapterEdit"
                         , fileInputId = fileInputId
                         , narrationId = chapter.narrationId
                         }
            )

        Nothing ->
          ( model, Cmd.none )

    AddMediaFileError error ->
      -- Bah. We don't know which type was uploaded, so we assume we
      -- can safely turn off both spinners. Sigh.
      ( { model | banner = errorBanner error.message
                , uploadingAudio = False
                , uploadingBackgroundImage = False
        }
      , Cmd.none
      )

    AddMediaFileSuccess resp ->
      case model.narration of
        Just narration ->
          case model.chapter of
            Just chapter ->
              let
                updatedFiles = updateNarrationFiles narration.files resp
                updatedNarration = { narration | files = updatedFiles }
                updatedChapter = updateChapter chapter resp
                modelWithoutUploadFlag =
                  if resp.type_ == "audio" then
                    { model | uploadingAudio = False }
                  else
                    { model | uploadingBackgroundImage = False }
              in
                ( { modelWithoutUploadFlag | narration = Just updatedNarration
                                           , chapter = Just updatedChapter
                                           , chapterModified = True
                  }
                , Cmd.none
                )

            Nothing ->
              ( model, Cmd.none )

        Nothing ->
          ( model, Cmd.none )

    SaveChapter ->
      case model.chapter of
        Just chapter ->
          ( { model | banner = Nothing, flash = Nothing }
          , ChapterEditApp.Api.saveChapter chapter
          )

        Nothing ->
          ( model, Cmd.none )

    PublishChapter ->
      ( { model | showPublishChapterDialog = True }
      , Cmd.none
      )

    CancelPublishChapter ->
      ( { model | showPublishChapterDialog = False }
      , Cmd.none
      )

    ConfirmPublishChapter ->
      ( { model | banner = Nothing
                , flash = Nothing
                , showPublishChapterDialog = False
        }
      , Task.perform PublishChapterWithTime Time.now
      )

    PublishChapterWithTime time ->
      case model.chapter of
        Just chapter ->
          let
            publishTimestamp = Just <| toUtcString time
            updatedChapter =
              { chapter | published = publishTimestamp }
          in
            ( { model | chapter = Just updatedChapter }
            , ChapterEditApp.Api.saveChapter updatedChapter
            )

        Nothing ->
          ( model, Cmd.none )

    SaveChapterResult (Err error) ->
      ( model, showFlashMessage ChapterSaveFlash <| errorBanner "Error saving chapter" )

    SaveChapterResult (Ok resp) ->
      case model.chapter of
        Just chapter ->
          case resp of
            Http.GoodStatus_ _ _ ->
              case chapter.published of
                Just published ->
                  ( model
                  , Nav.pushUrl model.key <| "/chapters/" ++ (String.fromInt chapter.id)
                  )

                Nothing ->
                  ( { model | chapterModified = False }
                  , showFlashMessage ChapterSaveFlash <| successBanner "Saved"
                  )
            Http.BadStatus_ metadata _ ->
              ( model
              , showFlashMessage ChapterSaveFlash <| errorBanner <| "Error saving chapter, status code " ++ (String.fromInt metadata.statusCode)
              )

            _ ->
              ( model
              , showFlashMessage ChapterSaveFlash <| errorBanner "Error saving chapter, network error"
              )

        Nothing ->
          ( model, Cmd.none )

    SaveNewChapter ->
      case model.chapter of
        Just chapter ->
          ( { model | savingChapter = True }
          , if model.savingChapter then
              Cmd.none
            else
              ChapterEditApp.Api.createChapter chapter
          )

        Nothing ->
          ( model, Cmd.none )

    PublishNewChapter ->
      ( { model | savingChapter = True }
      , if model.savingChapter then
          Cmd.none
        else
          Task.perform PublishNewChapterWithTime Time.now
      )

    PublishNewChapterWithTime time ->
      case model.chapter of
        Just chapter ->
          let
            publishTimestamp = Just <| toUtcString time
            updatedChapter = { chapter | published = publishTimestamp }
          in
            ( { model | chapter = Just updatedChapter }
            , ChapterEditApp.Api.createChapter updatedChapter
            )

        Nothing ->
          ( model, Cmd.none )

    SaveNewChapterResult (Err error) ->
      ( { model | banner = errorBanner "Error saving chapter"
                , savingChapter = False
        }
      , Cmd.none
      )

    SaveNewChapterResult (Ok chapter) ->
      ( { model | banner = Nothing
                , savingChapter = False
                , chapterModified = False
        }
      , Nav.pushUrl model.key <| "/chapters/" ++ (String.fromInt chapter.id) ++ "/edit"
      )

    UpdateChapterSearchTerm newTerm ->
      ( { model | narrationChapterSearchTerm = newTerm }
      , Cmd.none
      )

    SearchNarrationChapters searchTerm ->
      ( { model | narrationChapterSearchLoading = True }
      , case model.narration of
          Just narration ->
            ChapterEditApp.Api.searchNarrationChapters narration.id model.narrationChapterSearchTerm
          Nothing ->
            Cmd.none
      )

    NarrationChapterSearchFetchResult (Err error) ->
      ( { model | narrationChapterSearchLoading = False
                , banner = bannerForHttpError error }
      , Cmd.none
      )

    NarrationChapterSearchFetchResult (Ok results) ->
      ( { model | narrationChapterSearchResults = Just results.results
                , narrationChapterSearchLoading = False
                , banner = Nothing
        }
      , Cmd.none
      )

    UpdateNarrationNotes newNotes ->
      let
        updatedNarration = case model.narration of
                             Just narration -> Just { narration | notes = newNotes }
                             Nothing -> Nothing
      in
        ( { model | narration = updatedNarration
                  , notesModified = True
          }
        , Cmd.none
        )

    SaveNarrationNotes ->
      ( model
      , case model.narration of
          Just narration ->
            ChapterEditApp.Api.saveNarrationNotes narration.id narration.notes
          Nothing ->
            Cmd.none
      )

    SaveNarrationNotesResult (Err error) ->
      ( model
      , showFlashMessage NarrationNotesSaveFlash <| errorBanner "Error saving notes"
      )

    SaveNarrationNotesResult (Ok _) ->
      ( { model | notesModified = False }
      , showFlashMessage NarrationNotesSaveFlash <| successBanner "Saved"
      )
