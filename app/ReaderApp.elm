module ReaderApp exposing (..)

import Html exposing (Html)

import Routing
import Common.Ports
import ReaderApp.Messages exposing (..)
import ReaderApp.Models exposing (..)
import ReaderApp.Update
import ReaderApp.Views

type alias Model = ReaderApp.Models.Model
type alias Msg = ReaderApp.Messages.Msg

initialState : Model
initialState =
  { state = Loader
  , chapter = Nothing
  , messageThreads = Nothing
  , backgroundMusic = True
  , musicPlaying = True
  , backgroundBlurriness = 0
  , reply = Nothing
  , showNewMessageUi = False
  , newMessageText = ""
  , newMessageRecipients = []
  , reactionSent = False
  , reaction = ""
  , banner = Nothing
  , referenceInformationVisible = False
  }

update : Msg -> Model -> (Model, Cmd Msg)
update = ReaderApp.Update.update

urlUpdate : Routing.Route -> Model -> (Model, Cmd Msg)
urlUpdate = ReaderApp.Update.urlUpdate

view : Model -> Html Msg
view = ReaderApp.Views.mainView

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch [ Common.Ports.pageScrollListener PageScroll
            , Common.Ports.markNarrationAsStarted NarrationStarted
            ]
