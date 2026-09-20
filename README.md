# HideFrames

A lightweight World of Warcraft addon that lets you hide almost any frame.
Alternative to MoveAnything / MoveAny. Just focused on hiding rather than moving though.

## Usage

| Command                       | Description                                   |
| ----------------------------- | --------------------------------------------- |
| `/hide`                       | Open the window                               |
| `/hide [frame1] [frame2] ...` | Add and hide one or more frames               |
| `/hide list`                  | Show what's tracked in this profile           |
| `/hide remove [frame]`        | Stop tracking a frame (shows it again)        |
| `/hide show [frame]`          | Un-hide a frame without untracking it         |
| `/hide profile [name]`        | Switch profiles (creates a new one if needed) |
| `/hide copy`                  | List every frame under your mouse             |
| `/hide copy [#]`              | Grab entry `#` from that list                 |
| `/hide reset`                 | Wipe the current profile                      |
| `/hide minimap`               | Toggle the minimap button                     |
| `/hide help`                  | Show this usage list                          |

## Features

* Multi-frame import
* Profiles
* Minimap button
* Simple GUI with checkboxes + remove buttons
* Frame name copier (`/fscopy`)

## Installation

Copy the `HideFrames` folder into your `Interface/AddOns` directory.
