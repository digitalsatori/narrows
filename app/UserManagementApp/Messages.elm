module UserManagementApp.Messages exposing (..)

import Http
import Common.Models exposing (UserInfo)
import UserManagementApp.Models exposing (UserListResponse)


type Msg
    = NoOp
    | UsersFetchResult (Result Http.Error UserListResponse)
    | SelectUser Int
    | UnselectUser
    | UpdateDisplayName String
    | UpdatePassword String
    | UpdateIsAdmin Bool
    | SaveUser
    | SaveUserResult (Result Http.Error (Http.Response String))
    | UpdateNewUserEmail String
    | UpdateNewUserDisplayName String
    | UpdateNewUserIsAdmin Bool
    | SaveNewUser
    | SaveNewUserResult (Result Http.Error UserInfo)
