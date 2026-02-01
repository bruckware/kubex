#!/usr/bin/env bash
#
#     script: kubex.sh
#    purpose: Kubernetes inspection tool for Linux Bash shell
#    version: 1.0.0
#    license: MIT
#     author: Hamed Davodi <retrogaming457 [at] gmail [dot] com>
# repository: https://github.com/bruckware/kubex
#


requirement() {

    ESC=$'\033'
    RESET="${ESC}[0m"
    GREEN="${ESC}[32m"
    WHITE="${ESC}[37m"
    BLUE="${ESC}[38;2;40;180;255m"
    BRIGHT_WHITE="${ESC}[97m"
    MSG_PREFIX="${BLUE}[kubex]${RESET}"
    export GUM_CHOOSE_HEADER_FOREGROUND="#FF7F27"
    export GUM_CHOOSE_CURSOR_FOREGROUND="#32B4FF"
    export GUM_CHOOSE_SELECTED_FOREGROUND="#3282F6"

    local tool
    for tool in kubectl gum; do
       command -v "$tool" >/dev/null 2>&1 || {
          printf '%s\n' "${MSG_PREFIX} ERROR (1): $tool cli not found in PATH."
          return 1
       }
    done

    return 0

}



kubernetes() {

    while true; do
        local options=(
            " switch: CONTEXT"
            " switch: NAMESPACE"
            "   view: SECRET"
            "inspect: POD"
            "inspect: SERVICE"
            "inspect: NODE"
            "{exit}"
        )

        local header="${MSG_PREFIX} Select option:"
        local selected

       select_prompt options selected || return 1

        case "$selected" in
            *POD)        get_pod ;;
            *SECRET)     get_secret ;;
            *SERVICE)    get_service ;;
            *CONTEXT)    set_context ;;
            *NAMESPACE)  set_namespace ;;
            *NODE)       get_node ;;
            {exit})      return 0 ;;
        esac
    done

}


set_context() {

    local selected
    local -a contexts=()

    mapfile -t contexts < <(kubectl config get-contexts -o name 2>/dev/null)

    if [[ ${#contexts[@]} -eq 0 ]]; then
        printf '%s\n' "${MSG_PREFIX} No contexts found."
        return 1
    fi

    local options=("[Return to Main]" "${contexts[@]}")
    local header="${MSG_PREFIX} SWITCH CONTEXT:"

    select_prompt options selected || return 1

    [[ "$selected" == "[Return to Main]" ]] && return 0

    kubectl config use-context "$selected" >/dev/null || {
       printf '%s\n' "${MSG_PREFIX} ERROR (2): failed to set context."
       return 1
    }

    printf '%s\n' "${MSG_PREFIX} current-context set to ${GREEN}${selected}${RESET}"

}




set_namespace() {

    local selected
    local -a namespaces=()

    mapfile -t namespaces < <(
        kubectl get namespace \
            --request-timeout=5s \
            -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null
    )

    if [[ ${#namespaces[@]} -eq 0 ]]; then
        printf '%s\n' "${MSG_PREFIX} No namespaces found."
        return 1
    fi

    local options=("[Return to Main]" "${namespaces[@]}")
    local header="${MSG_PREFIX} SWITCH NAMESPACE:"
    select_prompt options selected || return 1

    [[ "$selected" == "[Return to Main]" ]] && return 0

    kubectl config set-context --current --namespace="$selected" >/dev/null || {
       printf '%s\n' "${MSG_PREFIX} ERROR (3): failed to set namespace."
       return 1
    }

    printf '%s\n' "${MSG_PREFIX} namespace set to ${GREEN}${selected}${RESET}"

}







get_pod() {

    local pod_option selected_pod cont_name options selection
    local pod_ops=("[Return to Main]" "disk_use" "exec" "logs" "labels" "manifest" "describe")
    local header="${MSG_PREFIX} Inspect POD:"
    select_prompt pod_ops pod_option || return 1

    [[ "$pod_option" == "[Return to Main]" ]] && return 0

    mapfile -t pods < <(
        kubectl get pods --request-timeout=5s -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
    )

    if [[ ${#pods[@]} -eq 0 ]]; then
        printf '%s\n' "${MSG_PREFIX} No pods found."
        return 1
    fi

    local options=("[Return to Main]" "${pods[@]}")
    local header=$(printf "%s\n%s" "${MSG_PREFIX} Found ${#pods[@]} pods." "Select one:")
    select_prompt options selected_pod || return 1

   [[ "$selected_pod" == "[Return to Main]" ]] && return 0

    case "$pod_option" in

        disk_use)   
            pod_disk
            ;;
        logs)           
            if command -v jq >/dev/null 2>&1; then
               kubectl logs "pod/$selected_pod" --tail=10 | grep -i "error" | jq
            else
               kubectl logs "pod/$selected_pod" --tail=10 | grep -i "error"
            fi 
            ;;
        exec)       
            if ! kubectl exec -it "pod/$selected_pod" -- /bin/bash 2>/dev/null; then
              kubectl exec -it "pod/$selected_pod" -- /bin/sh
            fi
            ;;
        labels)     
            if command -v jq >/dev/null 2>&1; then
                kubectl get "pod/$selected_pod" -o jsonpath='{.metadata.labels}' | jq .
            else
                kubectl get "pod/$selected_pod" -o jsonpath='{.metadata.labels}'
            fi
            ;;
        manifest)
            if yq --version 2>/dev/null | grep -q 'mikefarah'; then
                kubectl get "pod/$selected_pod" -o yaml | yq -P
            else
                kubectl get "pod/$selected_pod" -o yaml
            fi
            ;;
        describe)   
            kubectl describe "pod/$selected_pod" 
            ;;
    esac


}


pod_disk() {

    local cont_name selected_mount options

    cont_name=$(kubectl get pod/"$selected_pod" -o jsonpath='{.spec.containers[0].name}')
    [[ -z "$cont_name" ]] && { printf '%s\n' "${MSG_PREFIX} No container found in pod."; return 1; }

    mapfile -t options < <(
        kubectl exec -i "pod/$selected_pod" -c "$cont_name" -- sh -c \
        "mount | cut -d ' ' -f3 | grep -Ev '^/(proc|run|etc|sys|dev|dev/pts|dev/shm|mqueue|controller)'"
    )

    [[ ${#options[@]} -eq 0 ]] && { printf '%s\n' "${MSG_PREFIX} No relevant mount points found."; return 1; }

    local header=$(printf "%s\n%s" "${MSG_PREFIX} Relevant mount points of $selected_pod pod." "Select one:")
    select_prompt options selected_mount || return 1

    kubectl exec -i "pod/$selected_pod" -c "$cont_name" -- sh -c "df -h $selected_mount"

}




get_secret() {

    local secret_option selected_secret keys decode_option
    local secret_ops=("[Return to Main]" "data" "labels" "manifest" "describe")
    local header="${MSG_PREFIX} Inspect SECRET:"
    select_prompt secret_ops secret_option || return 1

    [[ "$secret_option" == "[Return to Main]" ]] && return 0

    mapfile -t secrets < <(
        kubectl get secret --request-timeout=5s -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
    )

    [[ ${#secrets[@]} -eq 0 ]] && { printf '%s\n' "${MSG_PREFIX} No secrets found."; return 1; }

    local options=("[Return to Main]" "${secrets[@]}")
    local header="$(printf "%s\n%s" "${MSG_PREFIX} Found ${#secrets[@]} secrets." "Select one:")"
    select_prompt options selected_secret || return 1

    [[ "$selected_secret" == "[Return to Main]" ]] && return 0

    case "$secret_option" in
        data)
            secret_data 
            ;;
        labels)
            if command -v jq >/dev/null 2>&1; then
                kubectl get "secret/$selected_secret" -o jsonpath='{.metadata.labels}' | jq .
            else
                kubectl get "secret/$selected_secret" -o jsonpath='{.metadata.labels}'
            fi
            ;;
        manifest) 
            if yq --version 2>/dev/null | grep -q 'mikefarah'; then
                kubectl get "secret/$selected_secret" -o yaml | yq -P
            else
                kubectl get "secret/$selected_secret" -o yaml
            fi
            ;;
        describe) 
            kubectl describe "secret/$selected_secret" 
            ;;
    esac

}


secret_data() {

    local keys=()
    local selected_keys=()
    local decode_option="No"

    mapfile -t keys < <(kubectl get "secret/$selected_secret" -o go-template='{{range $k, $_ := .data}}{{println $k}}{{end}}')

    [[ ${#keys[@]} -eq 0 ]] && { printf '%s\n' "${MSG_PREFIX} No keys found in secret $selected_secret"; return 1; }
    local header="$(printf "%s\n%s" "${MSG_PREFIX} Found ${#keys[@]} keys in ${BRIGHT_WHITE}$selected_secret${RESET} secret." "Select keys (use Space/Tab):")"
    local limit=${#keys[@]}
    select_prompt keys selected_keys 2 || return 1

    [[ "$selected_keys" == "[Return to Main]" ]] && return 0

    gum confirm "${MSG_PREFIX} Base64 decode (Yes/No):" && decode_option="Yes"

    print_secret_keys

}


print_secret_keys() {

    local max_len=0 key val

    for key in "${selected_keys[@]}"; do
        (( ${#key} > max_len )) && max_len=${#key}
    done

    printf '%s\n' "${MSG_PREFIX} Secret Keys:"

    for key in "${selected_keys[@]}"; do
        val=$(kubectl get "secret/$selected_secret" -o go-template='{{ index .data "'"$key"'" }}')
        printf "%${max_len}s: " "$key"

        if [[ $decode_option == "Yes" ]]; then
            printf '%s\n' "${GREEN}$(printf '%s' "$val" | base64 -d)${RESET}"
        else
            printf '%s\n' "${GREEN}$val${RESET}"
        fi
    done
    
}



get_service() {

    local options=("[Return to Main]" "labels" "manifest" "describe")
    local header="${MSG_PREFIX} Inspect SERVICE:"
    local service_option selected_service

    select_prompt options service_option || return 1

    [[ "$service_option" == "[Return to Main]" ]] && return 0

    mapfile -t services < <(kubectl get service --request-timeout=5s -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

    [[ ${#services[@]} -eq 0 ]] && { printf '%s\n' "No services found"; return 1; }

    local service_options=("[Return to Main]" "${services[@]}")
    local header="$(printf "%s\n%s" "${MSG_PREFIX} Found ${#services[@]} services." "Select one:")"
    select_prompt service_options selected_service || return 1

    [[ "$selected_service" == "[Return to Main]" ]] && return 0

    case "$service_option" in
        labels)
            if command -v jq >/dev/null 2>&1; then
                kubectl get "svc/$selected_service" -o jsonpath='{.metadata.labels}' | jq .
            else
                kubectl get "svc/$selected_service" -o jsonpath='{.metadata.labels}'
            fi
            ;;
        manifest)
            if yq --version 2>/dev/null | grep -q 'mikefarah'; then
                kubectl get "svc/$selected_service" -o yaml | yq -P
            else
                kubectl get "svc/$selected_service" -o yaml
            fi
            ;;
        describe)
            kubectl describe "svc/$selected_service"
            ;;
    esac

}


get_node() {

    local options=("[Return to Main]" "list-wide" "describe" "labels")
    local header="${MSG_PREFIX} Inspect NODE:"
    local node_option selected_node

    select_prompt options node_option || return 1

    [[ "$node_option" == "[Return to Main]" ]] && return 0

    if [[ "$node_option" == "list-wide" ]]; then
        kubectl get node -o wide
        return 0
    fi

    mapfile -t nodes < <(kubectl get node --request-timeout=5s -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

    [[ ${#nodes[@]} -eq 0 ]] && { printf '%s\n' "${MSG_PREFIX} No nodes found"; return 1; }

    local node_options=("[Return to Main]" "${nodes[@]}")
    local header="$(printf "%s\n%s" "${MSG_PREFIX} Found ${#nodes[@]} nodes." "Select one:")"
    select_prompt node_options selected_node || return 1

    [[ "$selected_node" == "[Return to Main]" ]] && return 0

    case "$node_option" in
        describe)
            kubectl describe "node/$selected_node"
            ;;
        labels)
            if command -v jq >/dev/null 2>&1; then
                kubectl get "node/$selected_node" -o jsonpath='{.metadata.labels}' | jq .
            else
                kubectl get "node/$selected_node" -o jsonpath='{.metadata.labels}'
            fi
            ;;
    esac

}


select_prompt() {

    local -n _options=$1
    local -n _result=$2
    local mode=${3:-1}

    _result=()

    [[ ${#_options[@]} -eq 0 ]] && {
        printf '%s\n' "${MSG_PREFIX} ERROR (4): no options provided for select prompt." >&2
        return 1
    }

    local cmd

    if (( ${#_options[@]} > 15 )); then
        cmd=(gum filter --width 20 --height 15 --header "$header")
    else
        cmd=(gum choose --header "$header")
        [[ $mode -eq 1 ]] && cmd+=(--select-if-one)
        [[ $mode -eq 2 ]] && cmd+=(--no-limit)
    fi

    cmd+=("${_options[@]}")

    mapfile -t _result < <("${cmd[@]}")

    [[ ${#_result[@]} -eq 0 ]] && return 1

    for item in "${_result[@]}"; do
        if [[ "$item" == "[Return to Main]" ]]; then
            _result=("[Return to Main]")
            return 0
        fi
    done

    if [[ $mode -eq 1 ]]; then
        _result="${_result[0]}"
    fi

}


main(){

    requirement || return 1
    kubernetes  || return 1

}


main