#!/bin/bash

# ============================================================
#  UFW TUI PRO v7.0 – Gerenciador do UFW por Nícolas Brandão
#  Tema DARK • Dependências ANTES do dialog • Logo ajustado
# ============================================================


# ------------------------------------------------------------
# LOGO (título + teclado)
# ------------------------------------------------------------
logo="
        GERENCIADOR DO UFW
          por Nícolas Brandão

              ,----------------------------------------------------,
              | [][][][][]  [][][][][]  [][][][]  [][__]  [][][][] |
              |                                                    |
              |  [][][][][][][][][][][][][][_]    [][][]  [][][][] |
              |  [_][][][][][][][][][][][][][ |   [][][]  [][][][] |
              | [][_][][][][][][][][][][][][]||     []    [][][][] |
              | [__][][][][][][][][][][][][__]    [][][]  [][][]|| |
              |   [__][________________][__]              [__][]|| |
              \`----------------------------------------------------'
"


# ------------------------------------------------------------
# 1) VERIFICAR DEPENDÊNCIAS (ANTES do dialog)
# ------------------------------------------------------------
faltando=()

command -v ufw >/dev/null 2>&1 || faltando+=("ufw")
command -v dialog >/dev/null 2>&1 || faltando+=("dialog")

if [ ${#faltando[@]} -gt 0 ]; then
    clear
    echo -e "\n=============================="
    echo -e "   🔧 VERIFICANDO DEPENDÊNCIAS"
    echo -e "==============================\n"
    echo "Faltam os seguintes pacotes:"
    for p in "${faltando[@]}"; do
        echo " - $p"
    done

    echo ""
    read -p "Instalar automaticamente? (s/n): " inst

    if [[ "$inst" =~ ^[sS]$ ]]; then
        apt update -y
        for p in "${faltando[@]}"; do
            apt install -y "$p"
        done
    else
        echo "❌ Não é possível continuar sem dependências."
        exit 1
    fi
fi


# ------------------------------------------------------------
# 2) DARK THEME real para dialog
# ------------------------------------------------------------
export DIALOGRC=/tmp/dialog_dark.rc

cat << EOF > /tmp/dialog_dark.rc
screen_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,ON)
border_color = (CYAN,BLACK,ON)
title_color = (CYAN,BLACK,ON)
button_active_color = (BLACK,WHITE,ON)
button_inactive_color = (WHITE,BLACK,ON)
EOF

DIALOG="dialog --ascii-lines --no-shadow"


# ------------------------------------------------------------
# 3) FUNÇÕES PRINCIPAIS
# ------------------------------------------------------------

menu_principal() {
    while true; do
        escolha=$($DIALOG --clear \
            --backtitle "UFW TUI PRO – Brasil Cloud" \
            --title " MENU PRINCIPAL " \
            --menu "Selecione uma opção:" 20 60 10 \
            1 "Status do Firewall" \
            2 "Listar regras numeradas" \
            3 "Adicionar regra ALLOW" \
            4 "Adicionar regra DENY" \
            5 "Remover regra" \
            6 "Habilitar UFW" \
            7 "Desabilitar UFW" \
            8 "Resetar UFW (perigoso)" \
            0 "Sair" \
            3>&1 1>&2 2>&3)

        [ $? -ne 0 ] && exit

        case $escolha in
            1) mostrar_status ;;
            2) listar_regras ;;
            3) add_regra "allow" ;;
            4) add_regra "deny" ;;
            5) remover_regra ;;
            6) sudo ufw enable; $DIALOG --msgbox "UFW habilitado!" 8 35 ;;
            7) sudo ufw disable; $DIALOG --msgbox "UFW desabilitado!" 8 35 ;;
            8) resetar ;;
            0) exit ;;
        esac
    done
}


mostrar_status() {
    sudo ufw status verbose > /tmp/ufwstatus.txt
    $DIALOG --title "Status do Firewall" --textbox /tmp/ufwstatus.txt 25 80
}


listar_regras() {
    dados=$(sudo ufw status numbered)

    if ! echo "$dados" | grep -q "\["; then
        $DIALOG --msgbox "Nenhuma regra encontrada." 10 40
    else
        echo "$dados" > /tmp/rules.txt
        $DIALOG --title "Regras do UFW" --textbox /tmp/rules.txt 25 80
    fi
}


add_regra() {
    tipo=$1

    portas=$($DIALOG --inputbox "Portas (ex: 22 ou 22,80,443):" 10 50 "" 3>&1 1>&2 2>&3)
    ip=$($DIALOG --inputbox "IP / CIDR (ex: 177.x.x.x ou 10.0.0.0/24):" 10 50 "" 3>&1 1>&2 2>&3)
    proto=$($DIALOG --inputbox "PROTOCOLO (tcp/udp ou deixe vazio):" 10 50 "" 3>&1 1>&2 2>&3)

    IFS=',' read -ra portas_array <<< "$portas"

    for p in "${portas_array[@]}"; do
        p=$(echo "$p" | xargs)
        if [ -z "$proto" ]; then
            sudo ufw "$tipo" from "$ip" to any port "$p"
        else
            sudo ufw "$tipo" from "$ip" to any port "$p" proto "$proto"
        fi
    done

    $DIALOG --msgbox "Regra(s) adicionada(s) com sucesso!" 10 40
}


remover_regra() {
    dados=$(sudo ufw status numbered)
    if ! echo "$dados" | grep -q "\["; then
        $DIALOG --msgbox "Nenhuma regra para remover." 10 40
        return
    fi

    echo "$dados" > /tmp/remove.txt
    $DIALOG --textbox /tmp/remove.txt 25 80

    num=$($DIALOG --inputbox "Número da regra para remover:" 10 40 "" 3>&1 1>&2 2>&3)
    sudo ufw delete "$num"
    $DIALOG --msgbox "Regra removida!" 10 40
}


resetar() {
    $DIALOG --yesno "Resetar TODAS as regras? Esta ação é irreversível." 10 50
    if [ $? -eq 0 ]; then
        sudo ufw reset
        $DIALOG --msgbox "Firewall resetado!" 10 40
    fi
}


# ------------------------------------------------------------
# 4) Tela de abertura com o logo
# ------------------------------------------------------------
$DIALOG --backtitle "BRASIL CLOUD — UFW TUI PRO" \
        --title " Bem-vindo " \
        --msgbox "$logo" 20 90


# ------------------------------------------------------------
# 5) Carregar o menu principal
# ------------------------------------------------------------
menu_principal
