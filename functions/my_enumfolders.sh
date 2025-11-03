my_enumfolders() {
  # Usage: my_enumfolders [-f|--force] [base_dir=.]
  # Creates ./loot and ./report, plus report/{scratch.md,foothold.md,privesc.md}
  # Honors DRY_RUN=1 to preview actions. Use -f/--force to overwrite existing files.
  local force=0
  case "${1:-}" in
    -f|--force) force=1; shift ;;
  esac

  local base="${1:-$PWD}"
  local loot_dir="${base%/}/loot"
  local report_dir="${base%/}/report"
  local f_scratch="${report_dir}/scratch.md"
  local f_foothold="${report_dir}/foothold.md"
  local f_privesc="${report_dir}/privesc.md"

  # file contents
  local c_scratch="## Our working area ##  "
  local c_foothold="## These are the detailed steps to get foothold ##"
  local c_privesc="## These are the detailed steps to own the box ##"

  # helper: write a file (skip if exists unless force=1)
  _write_file() {
    local path="$1" content="$2"
    if [ -e "$path" ] && [ "$force" -ne 1 ]; then
      echo "⚠  Exists, skipping: $path"
      return 0
    fi
    if [ "${DRY_RUN:-0}" = "1" ]; then
      echo "ℹ  Would write: $path"
      echo "----"
      printf '%s\n' "$content"
      echo "----"
      return 0
    fi
    printf '%s\n' "$content" > "$path" && echo "✅ Wrote: $path"
  }

  echo "▶▶▶ Creating enumeration folders in: $base"
  # make dirs
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "ℹ  Would create dir: $loot_dir"
    echo "ℹ  Would create dir: $report_dir"
  else
    mkdir -p "$loot_dir" "$report_dir" && echo "✅ created  dirs: $loot_dir, $report_dir"
  fi

  # write files
  _write_file "$f_scratch"  "$c_scratch"
  _write_file "$f_foothold" "$c_foothold"
  _write_file "$f_privesc"  "$c_privesc"

  echo "ℹ  Done. Use DRY_RUN=1 to preview; add -f to overwrite existing files."
}

