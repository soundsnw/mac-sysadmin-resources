#!/bin/bash

# 
# For sysadmins who want a faster mouse cursor speed and keyboard repeat rate than what GUI preferences allow,
# and also want to disable animations
#


defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

defaults write -g QLPanelAnimationDuration -float 0

defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

defaults write com.apple.finder DisableAllAnimations -bool true

defaults write com.apple.dock launchanim -bool false

defaults write com.apple.dock expose-animation-duration -float 0.1

defaults write com.apple.Dock autohide-delay -float 0

defaults write com.apple.mail DisableReplyAnimations -bool true

defaults write com.apple.mail DisableSendAnimations -bool true

defaults write com.apple.Safari WebKitInitialTimedLayoutDelay 0.25

defaults write NSGlobalDomain KeyRepeat -int 0

defaults write -g InitialKeyRepeat -int 10

defaults write -g KeyRepeat -int 1

defaults write -g com.apple.mouse.scaling  7.0

defaults write -g com.apple.trackpad.scaling  7.0

defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

exit 0
