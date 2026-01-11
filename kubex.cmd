::
::     script: kubex.cmd
::    purpose: Kubernetes inspection tool for Windows Command-Prompt and PowerShell
::    version: 1.0.0
::    license: MIT
::     author: Hamed Davodi <retrogaming457 [at] gmail [dot] com>
:: repository: https://github.com/bruckware/kubex
::



@echo off
setlocal EnableDelayedExpansion

call :requirement || goto :eof

:MENU
call :kubernetes || goto :eof
goto :MENU

endlocal
goto :eof




:requirement
set "ESC="
set "RESET=%ESC%[0m"
set "GREEN=%ESC%[32m"
set "WHITE=%ESC%[37m"
set "BLUE=%ESC%[38;2;40;180;255m"
set "BRIGHT_WHITE=%ESC%[97m"
set "MSG_PREFIX=%BLUE%[kubex]%RESET%"
set "GUM_CHOOSE_HEADER_FOREGROUND=#FF7F27"
set "GUM_CHOOSE_CURSOR_FOREGROUND=#32B4FF"
set "GUM_CHOOSE_SELECTED_FOREGROUND=#3282F6"

set "WHERE_EXE=%SystemRoot%\System32\where.exe"
set "FINDSTR_EXE=%SystemRoot%\System32\findstr.exe"
if not exist "%WHERE_EXE%" ( echo %MSG_PREFIX% ERROR: where cli was not found at "%WHERE_EXE%" & exit /b 1 )
if not exist "%FINDSTR_EXE%" ( echo %MSG_PREFIX% ERROR: findstr cli was not found at "%FINDSTR_EXE%" & exit /b 1 )

"%WHERE_EXE%" /q gum.exe || ( echo %MSG_PREFIX% ERROR: gum cli was not found. & exit /b 1 )
"%WHERE_EXE%" /q kubectl.exe || ( echo %MSG_PREFIX% ERROR: kubectl cli was not found. & exit /b 1 ) 
goto :eof





:kubernetes
set "options=" switch: CONTEXT" " switch: NAMESPACE" "   view: SECRET" "inspect: POD"  "inspect: SERVICE"  "inspect: NODE" "{exit}""
set "header=%MSG_PREFIX% Select option:"
call :select_prompt 1 || exit /b 1

if "%selected%"=="{exit}" (
    exit /b 1
) else if "%selected:~-3%"=="EXT" (
    call :set_context || exit /b 1

) else if "%selected:~-3%"=="ACE" (
    call :set_namespace || exit /b 1

) else if "%selected:~-3%"=="RET" (
    call :get_secret || exit /b 1

) else if "%selected:~-3%"=="POD" (
    call :get_pod || exit /b 1

) else if "%selected:~-3%"=="ICE" (
    call :get_service || exit /b 1

) else if "%selected:~-3%"=="ODE" (
    call :get_node || exit /b 1
) 
goto :eof





:set_context
set "listing_command=kubectl.exe config get-contexts -o name | "%FINDSTR_EXE%" /n "^^""
call :build_indexed_list || exit /b 1

set "options=^"[Return to Main]^" %list%"
set "header=%MSG_PREFIX% SWITCH CONTEXT:"
call :select_prompt 1 || exit /b 1

if "%selected%"=="[Return to Main]" exit /b 0

kubectl.exe config use-context "%selected%" >nul || (
    echo %MSG_PREFIX% ERROR: failed to set context.
    exit /b 1
)
echo %MSG_PREFIX% current-context set to %GREEN%%selected%%RESET%
goto :eof




:set_namespace
set "listing_command=kubectl.exe get namespace --request-timeout=5s -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | "%FINDSTR_EXE%" /n "^^""
call :build_indexed_list || exit /b 1

set "options=^"[Return to Main^]" %list%"
set "header=%MSG_PREFIX% SWITCH NAMESPACE:"
call :select_prompt 1 || exit /b 1

if "%selected%"=="[Return to Main]" exit /b 0

kubectl.exe config set-context --current --namespace="%selected%" >nul || (
    echo %MSG_PREFIX% ERROR: failed to set namespace.
    exit /b 1
)
echo %MSG_PREFIX% namespace set to %GREEN%%selected%%RESET%
goto :eof





:get_pod
set "options=^"[Return to Main^]" "disk_use" "exec" "logs" "labels" "manifest" "describe""
set "header=%MSG_PREFIX% POD > Inspect:"
call :select_prompt 1 || exit /b 1
if "%selected%"=="[Return to Main]" exit /b 0

set "pod_option=%selected%"

set "listing_command=kubectl.exe get pods --request-timeout=5s -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | "%FINDSTR_EXE%" /n "^^""
call :build_indexed_list || exit /b 1

set "options=^"[Return to Main^]" %list%"
set "header=%MSG_PREFIX% Found %index% pods. Select one:"
call :select_prompt 1 || exit /b 1
if "%selected%"=="[Return to Main]" exit /b 0

set "selected_pod=%selected%"

if "%pod_option%"=="disk_use" ( 
    call :pod_disk || exit /b 1
) else if "%pod_option%"=="exec" ( 
    call :pod_exec 
) else if "%pod_option%"=="logs" ( 
    call :pod_logs 
) else if "%pod_option%"=="labels" ( 
    call :pod_labels 
) else if "%pod_option%"=="manifest" ( 
    call :pod_manifest 
) else if "%pod_option%"=="describe" ( 
    call :pod_describe 
)
goto :eof


:pod_disk
set "cont_name="
set "cont_command=kubectl.exe get pod/%selected_pod% -o jsonpath={.spec.containers[*].name}"
for /f "usebackq tokens=* delims=" %%a IN (`!cont_command!`) do set "cont_name=%%a"

set "options="
set "mount_command=kubectl.exe exec -i pod/%selected_pod% -c %cont_name% -- sh -c "mount ^| cut -d ' ' -f3 ^| grep -Ev '^/(proc^|run^|etc^|sys^|dev^|dev/pts^|dev/shm^|mqueue^|controller)'""
for /f "usebackq tokens=* delims=" %%a IN (`!mount_command!`) do set "options=!options! "%%a""

set "header=%MSG_PREFIX% Relevant mount points of %selected_pod% pod. Select one:"
call :select_prompt 1 || exit /b 1
if "%selected%"=="[Return to Main]" exit /b 0
kubectl.exe exec -i "pod/%selected_pod%" -c %cont_name% -- sh -c "df -h %selected%"
goto :eof


:pod_exec
kubectl.exe exec -it "pod/%selected_pod%" -- /bin/bash 2>nul || kubectl.exe exec -it "pod/%selected_pod%" -- /bin/sh 2>&1
goto :eof


:pod_logs
"%WHERE_EXE%" /q jq.exe && (
    kubectl.exe logs "pod/%selected_pod%" --tail=10 | "%FINDSTR_EXE%" /i /C:error | jq.exe
) || (
    kubectl.exe logs "pod/%selected_pod%" --tail=10 | "%FINDSTR_EXE%" /i /C:error
)
goto :eof


:pod_labels
"%WHERE_EXE%" /q jq.exe && (
    kubectl.exe get "pod/%selected_pod%" -o jsonpath={.metadata.labels} | jq.exe
) || (
    kubectl.exe get "pod/%selected_pod%" -o jsonpath={.metadata.labels}
)
goto :eof


:pod_manifest
yq.exe --version | "%FINDSTR_EXE%" mikefarah && (
    kubectl.exe get "pod/%selected_pod%" -o yaml | yq.exe -P
) || (
    kubectl.exe get "pod/%selected_pod%" -o yaml
)
goto :eof


:pod_describe
kubectl.exe describe "pod/%selected_pod%"
goto :eof






:get_service
set "options=^"[Return to Main^]" "labels" "manifest" "describe""
set "header=%MSG_PREFIX% SERVICE > Inspect:"
call :select_prompt 1 || exit /b 1

set "service_option=%selected%"

set "listing_command=kubectl.exe get service --request-timeout=5s -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | "%FINDSTR_EXE%" /n "^^""
call :build_indexed_list || exit /b 1

set "options=^"[Return to Main^]" %list%"
set "header=%MSG_PREFIX% Found %index% services. Select one:"
call :select_prompt 1 || exit /b 1
if "%selected%"=="[Return to Main]" exit /b 0

set "selected_service=%selected%"

if "%service_option%"=="labels" ( 
    call :service_labels 
) else if "%service_option%"=="manifest" ( 
    call :service_manifest 
) else if "%service_option%"=="describe" ( 
    call :service_describe 
)
goto :eof


:service_labels
"%WHERE_EXE%" /q jq.exe && (
    kubectl.exe get "svc/%selected_service%" -o jsonpath={.metadata.labels} | jq.exe
) || (
    kubectl.exe get "svc/%selected_service%" -o jsonpath={.metadata.labels}
)
goto :eof


:service_manifest
yq.exe --version | "%FINDSTR_EXE%" mikefarah && (
    kubectl.exe get "svc/%selected_service%" -o yaml | yq.exe -P
) || (
    kubectl.exe get "svc/%selected_service%" -o yaml
)
goto :eof


:service_describe
kubectl.exe describe "svc/%selected_service%"
goto :eof






:get_node
set "options=^"[Return to Main^]" "list-wide" "describe" "labels""
set "header=%MSG_PREFIX% NODE > Inspect:"
call :select_prompt 1 || exit /b 1
if "%selected%"=="[Return to Main]" exit /b 0

set "node_option=%selected%"

    if "%node_option%"=="list-wide" goto :node_list_wide

set "listing_command=kubectl.exe get node --request-timeout=5s -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | "%FINDSTR_EXE%" /n "^^""
call :build_indexed_list || exit /b 1

set "options=^"[Return to Main^]" %list%"
set "header=%MSG_PREFIX% Found %index% nodes. Select one:"
call :select_prompt 1 || exit /b 1
if "%selected%"=="[Return to Main]" exit /b 0

set "selected_node=%selected%"

if "%node_option%"=="describe" ( 
    call :node_describe 
) else if "%node_option%"=="labels" ( 
    call :node_labels
)
goto :eof


:node_list_wide
kubectl.exe get node -o wide
goto :eof


:node_describe
kubectl.exe describe "node/%selected_node%"
goto :eof


:node_labels
"%WHERE_EXE%" /q jq.exe && (
    kubectl.exe get "node/%selected_node%" -o jsonpath={.metadata.labels} | jq.exe
) || (
    kubectl.exe get "node/%selected_node%" -o jsonpath={.metadata.labels}
)
goto :eof






:get_secret
set "options=^"[Return to Main^]" "data" "labels" "manifest" "describe""
set "header=%MSG_PREFIX% SECRET > Inspect:"
call :select_prompt 1 || exit /b 1
if "%selected%"=="[Return to Main]" exit /b 0

set "secret_option=%selected%"

set "listing_command=kubectl.exe get secret --request-timeout=5s -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | "%FINDSTR_EXE%" /n "^^""
call :build_indexed_list || exit /b 1

set "options=^"[Return to Main^]" %list%"
set "header=%MSG_PREFIX% Found %index% secrets. Select one:"
call :select_prompt 1 || exit /b 1
if "%selected%"=="[Return to Main]" exit /b 0

set "selected_secret=%selected%"

if "%secret_option%"=="data" (
    call :secret_data || exit /b 1
) else if "%secret_option%"=="labels" (
    call :secret_labels 
) else if "%secret_option%"=="manifest" (
    call :secret_manifest 
) else if "%secret_option%"=="describe" ( 
    call :secret_describe 
)
goto :eof


:secret_data
set "listing_command=kubectl.exe get secret "%selected_secret%" -o jsonpath="{.data}""
call :build_json_list || exit /b 1

set "options=^"[Return to Main^]" %list%"
set "header=%MSG_PREFIX% Found %index% secret keys. Select keys (use Space/Tab):"
call :select_prompt 2 || exit /b 1
if "%selected%"=="[Return to Main]" exit /b 0

set "decode_option=No"
gum.exe confirm "%MSG_PREFIX% Base64 decode (Yes/No):" && set "decode_option=Yes"

call :print_json_list selected
goto :eof


:secret_labels
"%WHERE_EXE%" /q jq.exe && (
    kubectl.exe get "secret/%selected_secret%" -o jsonpath={.metadata.labels} | jq.exe
) || (
    kubectl.exe get "secret/%selected_secret%" -o jsonpath={.metadata.labels}
)
goto :eof


:secret_manifest
yq.exe --version | "%FINDSTR_EXE%" mikefarah && (
    kubectl.exe get "secret/%selected_secret%" -o yaml | yq.exe -P
) || (
    kubectl.exe get "secret/%selected_secret%" -o yaml
)
goto :eof


:secret_describe
kubectl.exe describe "secret/%selected_secret%"
goto :eof




:build_indexed_list
set "index="
set "list="
for /f "usebackq tokens=1,2 delims=:" %%a in (`!listing_command!`) do (
    set "index=%%a"
    set "list=!list! "%%b""
)
if not defined list exit /b 1
goto :eof




:build_json_list
set "index="
set "list="
for /f "usebackq delims=" %%a in (`!listing_command!`) do set "raw_json=%%a"

:: remove leading and trailing curly braces '{ ... }'
set "raw_json=!raw_json:~1,-1!"

for /f "usebackq tokens=1* delims==" %%A in (`set val_ 2^>nul`) do set "%%A="

for %%I in (%raw_json:,= %) do (
    set /a index+=1
    for /f "tokens=1* delims=:" %%K in ("%%I") do (
        set "key=%%~K"
        set "val=%%~L"
        set "key=!key:"=!"
        set "val=!val:"=!"
        
        set "val_!key!=!val!"
        set list=!list! "!key!"
    )
)

if not defined list exit /b 1
goto :eof



:print_json_list
:: using indirect expansion to preserve quotes if used
call set "key_arg=%%%~1%%"

call :max_length "%key_arg%"

if "%decode_option%"=="Yes" (
    
    "%WHERE_EXE%" /q base64.exe && (
        echo %MSG_PREFIX% Secret Keys ^(decoded^): 
    ) || (
        set "decode_option=No"
        echo %MSG_PREFIX% base64 cli required for decoding was not found.
        echo %MSG_PREFIX% printing secret data as in manifest.
        echo %MSG_PREFIX% Secret Keys:
    )

) else (
    echo %MSG_PREFIX% Secret Keys:
)

for %%M in (!key_arg!) do (

    set "key="
    set "val="
    set key=%%M
    set val=!val_%%M!

    call :get_length "!key!"
    set /a diff=max_len - len
    set "spaces="
    for /L %%i in (1,1,!diff!) do set "spaces=!spaces! "
    set "aligned_key="
    set "aligned_key=%WHITE%!spaces!!key!:%RESET% "
    
    :: echo with set to avoid newline
    <nul set /p ="!aligned_key!"

    if "!decode_option!"=="Yes" (

        set "decoded_val="
        for /f "tokens=* delims=" %%x in ('echo !val! ^| base64.exe -d') do (
            set decoded_val=%%x
            echo [32m!decoded_val![0m
        )

    ) else (
        echo [32m!val![0m

    )

)
goto :eof






:select_prompt
set "select_mode=%~1"

if not defined select_mode set "select_mode=1"

set "selected="
set "selected_items="
set "select_command="

if "%select_mode%"=="1" (
   call :single_select || exit /b 1
) else (
   call :custom_select || exit /b 1
)
goto :eof

:single_select
set "select_command=gum.exe choose --header="%header%" %options%"
if !select_item_count! gtr 15 set "select_command=gum.exe filter --header="%header%" %options%"
for /f "usebackq tokens=* delims=" %%a in (`!select_command!`) do set "selected=%%a"
if not defined selected exit /b 1
goto :eof

:custom_select
set "select_command=gum.exe choose --limit=%index% --header="%header%" %options%"
if !select_item_count! gtr 15 set "select_command=gum.exe filter --limit=%index% --header="%header%" %options%"
for /f "usebackq tokens=* delims=" %%a in (`!select_command!`) do set "selected_items=!selected_items! %%a"
if not defined selected_items exit /b 1
set "selected=!selected_items:~1!"
goto :eof




:max_length
set "list=%~1"
set "max_len=0"
for %%M in (%list%) do (
    call :get_length "%%~M"
    if !len! gtr !max_len! set "max_len=!len!"
)
goto :eof



:get_length
set "var=%~1"
set "len=0"
for /L %%i in (0,1,1024) do (
    if "!var:~%%i,1!"=="" (
        set "len=%%i"
        goto :eof
    )
)
goto :eof
