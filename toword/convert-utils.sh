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
    
    # Check if TikZ preprocessing is needed
    local processed_input="$input"
    if grep -q '\\begin{tikzpicture}' "$input"; then
        echo "TikZ code detected - preprocessing..."
        processed_input="${input%.tex}_processed.tex"
        
        # Run TikZ preprocessing
        python3 - <<'PYTHON_SCRIPT' "$input" "$processed_input"
import sys
import re
import hashlib
import os
import subprocess

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r') as f:
    content = f.read()

# Find all tikzpicture environments
tikz_pattern = r'\\begin{tikzpicture}.*?\\end{tikzpicture}'
matches = list(re.finditer(tikz_pattern, content, re.DOTALL))

print(f"Found {len(matches)} TikZ picture(s)")

# Process each TikZ block
for match in reversed(matches):  # Reversed to maintain string positions
    tikz_code = match.group(0)
    
    # Generate unique filename
    hash_obj = hashlib.sha1(tikz_code.encode())
    img_name = f"tikz_{hash_obj.hexdigest()[:16]}.png"
    
    if not os.path.exists(img_name):
        print(f"Compiling: {img_name}")
        
        # Create standalone LaTeX document
        tex_content = f"""\\documentclass{{standalone}}
\\usepackage{{tikz}}
\\usetikzlibrary{{positioning}}
\\usetikzlibrary{{backgrounds}}
\\usetikzlibrary{{arrows.meta}}
\\usetikzlibrary{{calc}}
\\usepackage{{graphicx}}
\\begin{{document}}
{tikz_code}
\\end{{document}}
"""
        
        tex_file = f"{img_name[:-4]}.tex"
        pdf_file = f"{img_name[:-4]}.pdf"
        
        with open(tex_file, 'w') as f:
            f.write(tex_content)
        
        # Compile to PDF
        subprocess.run(['pdflatex', '-interaction=batchmode', tex_file],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Convert to PNG
        subprocess.run(['convert', '-density', '300', pdf_file, img_name],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Cleanup
        for ext in ['.tex', '.pdf', '.log', '.aux']:
            try:
                os.remove(f"{img_name[:-4]}{ext}")
            except:
                pass
    
    # Replace TikZ code with includegraphics
    replacement = f"\\includegraphics{{{img_name}}}"
    content = content[:match.start()] + replacement + content[match.end():]

# Write processed file
with open(output_file, 'w') as f:
    f.write(content)

print(f"Preprocessed file: {output_file}")
PYTHON_SCRIPT
        
        if [ $? -ne 0 ]; then
            echo "Error: TikZ preprocessing failed"
            return 1
        fi
    fi
    
    # Build the pandoc command (no raw_tex needed now!)
    local cmd=(pandoc "$processed_input"
        --filter pandoc-crossref)
    
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
    
    local exit_code=$?
    
    # Cleanup
    if [ "$processed_input" != "$input" ]; then
        command rm -f "$processed_input"
    fi
    
    if [ $exit_code -eq 0 ]; then
        # Clean up generated TikZ images
        if ls tikz_*.png >/dev/null 2>&1; then
            echo "Cleaning up generated TikZ images..."
            command rm -f tikz_*.png
        fi
        echo "Conversion successful!"
    else
        echo "Error: Pandoc conversion failed"
        return 1
    fi
}
