It's often handy to switch between looking at a folder's contents in Finder, and running command-line utilities in it. You can switch from command line to GUI with a simple `open .` to view your shell's working directory in Finder, but the reverse isn't as easy.

*Except now it is!* After installing this app as a Finder toolbar button, you can click its icon in (just about) any Finder window to open a new Terminal window, with your shell's working directory automatically switched to the Finder window's folder. Or you can hold the **fn** or **shift** key down as you click, to open the folder in a new Terminal tab, instead of a new window.

If you prefer [iTerm](https://iterm2.com) to Apple's Terminal, see [Open in iTerm](https://github.com/jakshin/open-in-iterm).


## Installation & Setup

### Step 1: Clone and build

```bash
git clone https://github.com/jakshin/open-in-terminal.git
cd open-in-terminal
./build.sh
```

This will create `Open In Terminal.app`.

### Step 2: Drag the application into your Finder toolbar

Hold the **command** key down and drag `Open In Terminal.app` into your Finder toolbar:

![[Hold command and drag]](Hold%20command%20and%20drag.png)

### Step 3: Allow assistive access

Open System Preferences, and navigate to **Security & Privacy > Privacy > Accessibility**. If the lock icon in the lower left is closed, click it and enter your password. Drag `Open In Terminal.app` into the right-hand section of the System Preferences window, and ensure that its checkbox is checked:

![[screenshot]](Allow%20assistive%20access.png)

If you skip this step, you may receive an error that "Open In Terminal is not allowed assistive access" when you attempt to use the app.


## Uninstallation

To uninstall the app, hold the **command** key down and drag its icon out of your Finder toolbar, then delete it.
