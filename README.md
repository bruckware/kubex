# kubex
**Interactive Kubernetes inspection tool for Windows and Linux shells.**

`kubex` is designed to simplify common Kubernetes management tasks on command-line. It provides quick access to frequently used `kubectl` queries including:

- Switching contexts 
- Switching namespaces
- View and decode secret data
- Check disk usage of pods
- Execute interactive shells inside pods
- View logs and manifest of various Kubernetes objects


Main motivations behind developing this scripting tool:

- Creating a utility that leverages the native Kubernetes command-line interface for cluster queries
- Eliminating the need for multiple standalone utilities, each dedicated to a single task
- Providing an easy-to-customize script that users can easily add other day-to-day queries for their specific workflows


## Setup
On both Windows and Linux, ensure dependencies are installed and simply place the script in PATH to use it. (Windows recommended location: `%USERPROFILE%\AppData\Local\bin`, Linux recommended location: `~/.local/bin/kubex`)
    
    
### Windows (Batch-Script)

```batch
mkdir %USERPROFILE%\AppData\Local\bin
copy kubex\kubex.cmd "%USERPROFILE%\AppData\Local\bin\"
:: Add `%USERPROFILE%\AppData\Local\bin` to the PATH and restart running shell
```


### Linux (Bash-Script)

```bash
mkdir -p ~/.local/bin
cp kubex/kubex.sh ~/.local/bin/kubex
chmod +x ~/.local/bin/kubex
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```



### Dependencies

- [kubectl](https://kubernetes.io/docs/tasks/tools/) → Kubernetes official command-line interface
- [gum](https://github.com/charmbracelet/gum) → gum (Charmbracelet) for select prompts.
  
#### Additional dependency only on Windows:
- `base64` — install using chocolately `choco install base64`


## Notes

- `kubex` does NOT execute destructive commands (e.g., deleting object, draining node) and does not require Administrator or root privileges. `kubex` is only intended for inspection and monitoring purposes.

#### Windows specific
- Be aware of Windows batch limitations regarding variable length. Therefore, when working with large Kubernetes clusters that contain a high number of objects (contexts, namespaces, pods, secrets, etc.), the generated selection lists can become very long (e.g. hundreds of pod names can exceed variable size limit of 8KB). In such cases, avoid using `kubex.cmd` and instead use `kubex.sh` via WSL.

- `EnableExtensions` is enabled by default on Windows (since NT 4.0).
If it has been explicitly disabled on your system, it must be enabled before running `swa`.

- ANSI escape sequences are used and a terminal that supports ANSI escape sequences is required. Native terminals of Windows 10 (build ≥ 10586) support ANSI escape sequences by default.


