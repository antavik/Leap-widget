# Uninstalling Leap

## The easy way

1. Open Leap.
2. Choose **Help ▸ Uninstall Leap…**.
3. Read the confirmation, then click **Uninstall**.

![The uninstall confirmation dialog](assets/uninstall-alert.png)
<!-- SHOT: the warning alert with Uninstall and Cancel buttons -->

Leap moves itself and its settings to the Trash and quits. The widgets vanish
from the Desktop and Notification Center on their own, within a minute.

If Leap was installed with Homebrew, it hands the job to `brew` instead, so
Homebrew's own records stay correct. You do not have to do anything different —
Leap works out how it was installed.

## The two folders macOS will not let Leap delete

macOS keeps `~/Library/Containers` out of reach of every app except Finder, so
two sandbox folders survive the uninstall:

- `~/Library/Containers/com.antavik.leap`
- `~/Library/Containers/com.antavik.leap.widget`

Leap names them on the way out and offers **Show in Finder**. Drag them to the
Trash there and you are done. They hold a few megabytes and nothing personal.

No password lifts this restriction — it needs Full Disk Access, which is not
something `sudo` can grant.

![The leftovers dialog with Show in Finder](assets/uninstall-leftovers.png)
<!-- SHOT: the informational alert listing the two container paths -->

## From the Terminal

If you installed with Homebrew:

```sh
brew uninstall --cask --zap leap
```

Without `--zap`, the app goes but its settings stay — that is Homebrew's
convention, not Leap's.

For a downloaded copy, drag Leap to the Trash, then clear the rest:

```sh
rm -rf ~/Library/Preferences/com.antavik.leap.plist \
       ~/Library/Containers/com.antavik.leap \
       ~/Library/Containers/com.antavik.leap.widget \
       "$HOME/Library/Application Scripts/com.antavik.leap" \
       "$HOME/Library/Application Scripts/com.antavik.leap.widget" \
       "$HOME/Library/Saved Application State/com.antavik.leap.savedState" \
       ~/Library/Caches/com.antavik.leap
```

The two `Containers` entries need Full Disk Access for whichever terminal app
runs this (**System Settings ▸ Privacy & Security ▸ Full Disk Access**). Finder
removes them with no setup at all.

## Just dragging it to the Trash

That works too. It leaves a few megabytes of settings behind, which the commands
above clear out.

## A widget that stays behind

A widget whose app is gone shows an empty placeholder until macOS notices.
Right-click it and choose **Remove Widget** to be rid of it immediately.

Next: [Support and Feedback](support.md).
