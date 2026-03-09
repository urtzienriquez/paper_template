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
    
    # Build the pandoc command
    local cmd=(pandoc "$input"
        --filter pandoc-crossref
        --bibliography=zotero.bib
        --bibliography=packages.bib
        --lua-filter refsection-bibliographies.lua
        -csl global-ecology-and-biogeography.csl
        --lua-filter fix-inner-parens.lua
        --lua-filter fix-titleblock.lua)
    
    if [ "$use_move_figures" = true ]; then
        cmd+=(--lua-filter move-figures.lua)
    fi
    
    cmd+=(--reference-doc=latex7.dotx -o "$output")
    
    "${cmd[@]}"
}
