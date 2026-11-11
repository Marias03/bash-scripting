#!/usr/bin/env bash

usage() {
    echo "Использование: $0 [--path dirpath] [--mask mask] [--number number] command" >&2
    exit 1
}

dirpath="$PWD"
mask="*"
number=$(nproc 2>/dev/null || sysctl -n hw.ncpu)
command=""

# Разбор аргументов
while (( $# > 0 )); do
    case "$1" in
        --path)   [[ $# -ge 2 ]] || usage; dirpath=$2; shift 2 ;;
        --mask)   [[ $# -ge 2 ]] || usage; mask=$2; shift 2 ;;
        --number) [[ $# -ge 2 ]] || usage; number=$2; shift 2 ;;
        --*)      echo "Ошибка: неизвестный аргумент $1" >&2; usage ;;
        *)        command=$1; shift; break ;;
    esac
done

(( $# == 0 )) || { echo "Ошибка: лишние аргументы: $*" >&2; usage; }

# Проверки
if [[ ! -d "$dirpath" ]]; then
    echo "Ошибка: каталог '$dirpath' не существует" >&2; exit 1
fi
if [[ -z "$mask" ]]; then
    echo "Ошибка: маска не может быть пустой" >&2; exit 1
fi
if [[ ! "$number" =~ ^[1-9][0-9]*$ ]]; then
    echo "Ошибка: --number должен быть целым числом больше нуля" >&2; exit 1
fi
if [[ -z "$command" ]]; then
    echo "Ошибка: не указана команда" >&2; usage
fi
# Если указано имя без пути (например gzip), ищем его в PATH
if [[ "$command" != */* ]]; then
    command=$(command -v "$command") || { echo "Ошибка: команда не найдена" >&2; exit 1; }
fi
if [[ ! -f "$command" || ! -x "$command" ]]; then
    echo "Ошибка: '$command' не существует или нет права на исполнение" >&2; exit 1
fi

# Абсолютный путь к каталогу
dirpath=$(cd "$dirpath" && pwd)

# Список регулярных файлов по маске (без каталогов и символьных ссылок)
shopt -s nullglob
files=()
for f in "$dirpath"/$mask; do
    [[ -f "$f" && ! -L "$f" ]] && files+=("$f")
done

# Параллельный запуск: не более number процессов одновременно
running=0
for f in "${files[@]}"; do
    if (( running >= number )); then
        wait -n
        running=$(( running - 1 ))
    fi
    "$command" "$f" &
    running=$(( running + 1 ))
done

wait
exit 0
