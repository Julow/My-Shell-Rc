{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses, TypeSynonymInstances #-}
import Control.Monad
import Data.List
import System.Directory
import System.Environment
import XMonad
import XMonad.Actions.Minimize
import XMonad.Actions.SpawnOn
import XMonad.Actions.UpdatePointer
import XMonad.Actions.WindowBringer
import XMonad.Layout.BoringWindows
import XMonad.Layout.Spacing
import XMonad.Layout.Minimize
import XMonad.Layout.ResizableTile
import XMonad.Layout.SubLayouts
import XMonad.Layout.LayoutModifier
import XMonad.Layout.Tabbed
import XMonad.Prompt
import XMonad.Prompt.Shell
import XMonad.Util.EZConfig (additionalKeysP, removeKeysP)
import XMonad.Util.NamedWindows (getName)
import XMonad.Util.Run
import qualified XMonad.StackSet as W
import qualified Data.Map as M

-- ========================================================================== --
-- Utils

data Prompt_autocomplete = Prompt_autocomplete String

instance XPrompt Prompt_autocomplete where
  showXPrompt (Prompt_autocomplete prompt) = prompt
  commandToComplete _ c = c
  nextCompletion _ = getNextCompletion

home_dir = io $ getEnv "HOME"

-- Tabbed layout with no decoration
instance Shrinker CustomShrink where
  shrinkIt _ _ = []

tabbedWithoutDeco =
  let theme = def { fontName = "xft:", decoHeight = 0 } in
  tabbedBottom CustomShrink theme

-- ========================================================================== --
-- Lock screen

screen_timeout = 500
screen_timeout_locked = 20

set_dpms timeout = "xset dpms 0 0 " ++ show timeout

lock_screen = spawn (
    (set_dpms screen_timeout_locked) ++ ";"
    ++ "slock;"
    ++ (set_dpms screen_timeout) ++ ";"
    ++ "bash ~/.xreloadrc"
  )

-- ========================================================================== --
-- Browser

web_browser = "firefox"

-- ========================================================================== --
-- Password prompt
-- Ask the password manager

compl_no_empty _ "" = return []
compl_no_empty f s = f s

password_prompt prompt_conf = do
  home <- home_dir
  let pass_dir = home ++ "/notes/pass/"
  let pass_script = home ++ "/notes/_pass.sh"
  ps <- io $ getDirectoryContents pass_dir
  let ps' = filter (not . isPrefixOf ".") ps
  let compl = compl_no_empty $ mkComplFunFromList' ps'
  let get_password p = safeSpawn pass_script [ "get", pass_dir ++ p ]
  mkXPrompt (Prompt_autocomplete "Password: ") prompt_conf compl get_password

-- ========================================================================== --
-- Preset prompt
-- Prompt to execute a shell script located in the ~/.presets directory

preset_prompt prompt_conf = do
  home <- home_dir
  let preset_dir = home ++ "/.presets/"
  ws <- io $ getDirectoryContents preset_dir
  let ws' = filter (flip notElem [ ".", ".." ]) ws
  let open w = spawn ("source \"" ++ preset_dir ++ w ++ "\"")
  mkXPrompt (Prompt_autocomplete "Preset: ") prompt_conf (mkComplFunFromList' ws') open

-- ========================================================================== --
-- Window prompt
-- Show the list of windows, sorted by workspace
-- Similar to Xmonad.Prompt.Window

window_title ws w = do
  name <- show <$> getName w
  let tag = W.tag ws
  return ("[" ++ tag ++ "] " ++ name)

window_prompt prompt_conf = do
  wm <- windowMap' window_title
  let compl = mkComplFunFromList' (M.keys wm)
  let action = flip whenJust (windows . W.focusWindow) . flip M.lookup wm
  mkXPrompt (Prompt_autocomplete "Windows: ") prompt_conf compl action

-- ========================================================================== --
-- Centered layout
-- Improve Layout.Spacing by handling Shink and Expand messages

data CenteredLayout a = CenteredLayout Integer deriving (Show, Read)

instance LayoutModifier CenteredLayout a where
  handleMess (CenteredLayout step) m
    | Just Shrink <- fromMessage m = modify_lr (-step)
    | Just Expand <- fromMessage m = modify_lr step
    | otherwise = return Nothing
    where
      modify_lr d = do
        let m (Border t b r l) = Border t b (r + d) (l + d)
        _ <- sendMessage (ModifyWindowBorder m)
        return Nothing

centered_full sp step =
  ModifiedLayout (CenteredLayout step) $
  spacingRaw False (Border 0 0 0 0) False (Border 0 0 sp sp) True $
  Full

-- ========================================================================== --
-- main

prompt_conf = def {
  font = "xft:",
  promptBorderWidth = 0,
  height = 22,
  position = CenteredAt 0.5 0.5,
  promptKeymap = foldl (\m (k, a) -> M.insert k a m) emacsLikeXPKeymap [
    ((controlMask, xK_w), killWord Prev),
    ((controlMask, xK_Left), moveWord Prev),
    ((controlMask, xK_Right), moveWord Next)
  ]
}

layout = minimize $ boringWindows $ add_tabs (tiled_layout ||| centered_layout)
  where
    tiled_layout = ResizableTall 1 (5/100) (1/2) []
    centered_layout = centered_full 600 20
    add_tabs = subLayout [] tabbedWithoutDeco

main =
  xmonad $ def
  {
    focusFollowsMouse = False,
    borderWidth = 0,
    logHook = updatePointer (0.99, 0.001) (0, 0),
    layoutHook = layout,
    manageHook = manageSpawn <+> manageHook def,
    terminal = "xterm tmux"
  } `additionalKeysP`
  [

    -- Windows management

    -- SubTabbed merge/unmerge
    ("M-u", withFocused (\w -> focusDown >> sendMessage (mergeDir id w))),
    ("M-S-u", withFocused (sendMessage . UnMerge)),
    -- SubTabbed next/prev
    ("M-j", onGroup W.focusDown'),
    ("M-k", onGroup W.focusUp'),

    -- BoringWindows
    ("M-S-<Tab>", focusUp),
    ("M-<Tab>", focusDown),
    ("M-m", markBoring),
    ("M-S-m", clearBoring),

    -- Minimize/restore
    ("M-d", withFocused minimizeWindow),
    ("M-S-d", withLastMinimized maximizeWindowAndFocus),

    -- Shrink/expand vertically
    ("M-S-l", sendMessage MirrorShrink),
    ("M-S-h", sendMessage MirrorExpand),

    -- Control

    -- Lock screen
    ("M-z", lock_screen),

    -- Web browser
    ("M-S-<Backspace>", safeSpawnProg web_browser),

    -- Shell, window, preset prompts
    ("M-p", shellPrompt prompt_conf),
    ("M-S-p", window_prompt prompt_conf),
    ("M-S-o", preset_prompt prompt_conf),

    -- Password prompt
    ("M-;", password_prompt prompt_conf),

    -- Indicators
    ("M-`", safeSpawn "indicators.sh" []),

    -- Small features

    -- Screenshot drag/whole screen
    ("M-s", safeSpawn "screenshot.sh" ["interactive"]),
    ("M-S-s", safeSpawn "screenshot.sh" ["screen"]),

    -- Volume keys
    ("<XF86AudioLowerVolume>", safeSpawn "volume.sh" ["-5%"]),
    ("<XF86AudioRaiseVolume>", safeSpawn "volume.sh" ["+5%"]),
    -- Media keys
    ("<XF86AudioMute>", safeSpawn "volume.sh" ["toggle"]),
    ("<XF86AudioPlay>", spawnOn "9" "playerctl play-pause || spotify.sh"),
    ("<XF86AudioPrev>", safeSpawn "playerctl" ["previous"]),
    ("<XF86AudioNext>", safeSpawn "playerctl" ["next"]),

    -- Backlight keys
    ("<XF86MonBrightnessUp>", safeSpawn "brightness.sh" ["5"]),
    ("<XF86MonBrightnessDown>", safeSpawn "brightness.sh" ["-5"])

  ] `removeKeysP`
  [
    "M-S-q"
  ]
