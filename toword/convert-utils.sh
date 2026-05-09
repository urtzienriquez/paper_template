# copy the ".tex", ".bib" and ".csl" files here and run:
# toword [-m] -i input.tex -o output.docx

toword() {
    local input=""
    local output=""
    local use_move_figures=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--move-figures)
                use_move_figures=true
                shift
                ;;
            -i|--input)
                input="$2"
                shift 2
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: toword [-m] -i <input-file> -o <output-file>"
                echo "  -m, --move-figures    Move figures to bottom"
                echo "  -i, --input          Input file"
                echo "  -o, --output         Output file"
                return 1
                ;;
        esac
    done
    
    if [ -z "$input" ] || [ -z "$output" ]; then
        echo "Error: Both input and output files are required"
        echo "Usage: toword [-m] -i <input-file> -o <output-file>"
        return 1
    fi
    
    # Auto-detect TikZ usage
    local has_tikz=false
    if grep -q '\\begin{tikzpicture}' "$input"; then
        has_tikz=true
        echo "TikZ code detected - enabling TikZ processing"
    fi
    
    # Check for bibliography files
    local bib_files=("zotero.bib" "packages.bib")
    local missing_bibs=()
    
    for bib in "${bib_files[@]}"; do
        if [ ! -f "$bib" ]; then
            missing_bibs+=("$bib")
        fi
    done
    
    if [ ${#missing_bibs[@]} -gt 0 ]; then
        echo "Warning: Bibliography file(s) not found: ${missing_bibs[*]}"
        echo "Proceeding without these bibliography files..."
    fi
    
    # Build the pandoc command
    local cmd=(pandoc "$input")
    
    # Only add raw_tex extension if TikZ is present
    if [ "$has_tikz" = true ]; then
        cmd+=(--from latex+raw_tex)
        # CRITICAL: TikZ filter must run BEFORE pandoc-crossref
        cmd+=(--lua-filter tikz-to-image.lua)
    fi
    
    # Now run pandoc-crossref AFTER TikZ images are generated
    cmd+=(--filter pandoc-crossref)
    
    # Add bibliography files only if they exist
    [ -f "zotero.bib" ] && cmd+=(--bibliography=zotero.bib)
    [ -f "packages.bib" ] && cmd+=(--bibliography=packages.bib)
    
    cmd+=(--lua-filter refsection-bibliographies.lua
        -csl global-ecology-and-biogeography.csl
        --lua-filter fix-inner-parens.lua
        --lua-filter fix-titleblock.lua)
    
    if [ "$use_move_figures" = true ]; then
        cmd+=(--lua-filter move-figures.lua)
    fi
    
    cmd+=(--reference-doc=latex7.dotx -o "$output")
    
    # Run pandoc
    "${cmd[@]}"
    local exit_status=$?

    # Check if conversion was successful (or at least finished)
    if [ $exit_status -eq 0 ]; then
        # Use find to be safer and avoid globbing issues
        if ls tikz_*.png >/dev/null 2>&1; then
            echo "Cleaning up generated TikZ images..."
            command rm -f tikz_*.png
        fi
    else
        echo "Error: Pandoc conversion failed with exit code $exit_status."
        echo "Keeping TikZ images for debugging."
        return 1
    fi
}
