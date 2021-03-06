module Core.Models exposing (..)

import Browser.Navigation as Nav

import Core.Routes exposing (Route(..))
import Common.Models exposing (Banner, UserInfo, UserSession)
import ReaderApp
import CharacterApp
import DashboardApp
import NarrationCreationApp
import NarrationOverviewApp
import NarrationIntroApp
import ChapterEditApp
import ChapterControlApp
import CharacterCreationApp
import CharacterEditApp
import UserManagementApp
import NovelReaderApp
import ProfileApp
import EmailVerificationApp




type alias ResetPasswordResponse =
  { id : String }

type alias Model =
  { route : Route
  , key : Nav.Key
  , session : Maybe UserSession
  , banner : Maybe Banner
  , email : String
  , password : String
  , forgotPasswordUi : Bool
  , readerApp : ReaderApp.Model
  , characterApp : CharacterApp.Model
  , dashboardApp : DashboardApp.Model
  , narrationCreationApp : NarrationCreationApp.Model
  , narrationOverviewApp : NarrationOverviewApp.Model
  , narrationIntroApp : NarrationIntroApp.Model
  , chapterEditApp : ChapterEditApp.Model
  , chapterControlApp : ChapterControlApp.Model
  , characterCreationApp : CharacterCreationApp.Model
  , characterEditApp : CharacterEditApp.Model
  , userManagementApp : UserManagementApp.Model
  , novelReaderApp : NovelReaderApp.Model
  , profileApp : ProfileApp.Model
  , emailVerificationApp : EmailVerificationApp.Model
  }
