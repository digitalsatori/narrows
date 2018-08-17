module NovelReaderApp.Api exposing (..)

import Json.Decode as Json exposing (..)
import Http
import NovelReaderApp.Messages exposing (Msg, Msg(..))
import Common.Api.Json exposing (parseParticipantCharacter)
import NovelReaderApp.Models exposing (Chapter, Novel, Narration)


parseChapter : Json.Decoder Chapter
parseChapter =
    Json.map5 Chapter
        (field "id" int)
        (field "title" string)
        (maybe (field "audio" string))
        (maybe (field "backgroundImage" string))
        (field "text" Json.value)


parseNarration : Json.Decoder Narration
parseNarration =
    Json.map5 Narration
        (field "id" int)
        (field "title" string)
        (field "characters" <| list parseParticipantCharacter)
        (maybe (field "defaultAudio" string))
        (maybe (field "defaultBackgroundImage" string))


parseNovel : Json.Decoder Novel
parseNovel =
    Json.map4 Novel
        (field "token" string)
        (field "characterId" int)
        (field "narration" parseNarration)
        (field "chapters" <| list parseChapter)


fetchNovelInfo : String -> Cmd Msg
fetchNovelInfo novelToken =
  let
    novelApiUrl = "/api/novels/" ++ novelToken
  in
    Http.send NovelFetchResult <| Http.get novelApiUrl parseNovel
