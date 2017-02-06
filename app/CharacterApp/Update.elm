module CharacterApp.Update exposing (..)

import Http

import Routing

import Common.Models exposing (errorBanner)
import Common.Ports exposing (initEditor)

import CharacterApp.Api
import CharacterApp.Messages exposing (..)
import CharacterApp.Models exposing (..)


urlUpdate : Routing.Route -> Model -> (Model, Cmd Msg)
urlUpdate route model =
  case route of
    Routing.CharacterPage characterToken ->
      ( { model | characterToken = characterToken }
      , CharacterApp.Api.fetchCharacterInfo characterToken
      )
    _ ->
      (model, Cmd.none)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NoOp ->
      (model, Cmd.none)

    CharacterFetchError error ->
      let
        errorString = case error of
                        Http.UnexpectedPayload payload ->
                          "Bad payload: " ++ payload
                        Http.BadResponse status body ->
                          "Got status " ++ (toString status) ++ " with body " ++ body
                        _ ->
                          "Network stuff"
      in
        ( { model | banner = (Just { text = "Error fetching character: " ++ errorString
                                   , type' = "error"
                                   }) }
        , Cmd.none
        )

    CharacterFetchSuccess character ->
      ( { model | characterInfo = Just character }
      , Cmd.batch [ initEditor { elemId = "description-editor"
                               , narrationId = 0
                               , narrationImages = []
                               , chapterParticipants = []
                               , text = character.description
                               , editorType = "description"
                               , updatePortName = "descriptionContentChanged"
                               }
                  , initEditor { elemId = "backstory-editor"
                               , narrationId = 0
                               , narrationImages = []
                               , chapterParticipants = []
                               , text = character.backstory
                               , editorType = "description"
                               , updatePortName = "backstoryContentChanged"
                               }
                  ]
      )

    UpdateDescriptionText newDescription ->
      case model.characterInfo of
        Just character ->
          let
            updatedCharacter = { character | description = newDescription }
          in
            ({ model | characterInfo = Just updatedCharacter }, Cmd.none)
        Nothing ->
          (model, Cmd.none)

    UpdateBackstoryText newBackstory ->
      case model.characterInfo of
        Just character ->
          let
            updatedCharacter = { character | backstory = newBackstory }
          in
            ({ model | characterInfo = Just updatedCharacter }, Cmd.none)
        Nothing ->
          (model, Cmd.none)

    SaveCharacter ->
      case model.characterInfo of
        Just character ->
          let
            _ = Debug.log "Character to save" character
          in
            ( model
            , CharacterApp.Api.saveCharacter model.characterToken character
            )
        Nothing ->
          (model, Cmd.none)
    SaveCharacterError error ->
      ({ model | banner = errorBanner "Error saving character" }
      , Cmd.none)
    SaveCharacterSuccess resp ->
      if (resp.status >= 200) && (resp.status < 300) then
        (model, Cmd.none)
      else
        ( { model | banner = errorBanner <| "Error saving character, status code " ++ (toString resp.status) }
        , Cmd.none
        )
