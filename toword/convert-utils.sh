# copy the ".tex", ".bib" and ".csl" files here and run:
# toword [-m] -i input.tex -o output.docx

toword() {
    local input=""
    local output=""
    local use_move_figures=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--move-figures) use_move_figures=true; shift ;;
            -i|--input) input="$2"; shift 2 ;;
            -o|--output) output="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
    done
    
    if [ -z "$input" ] || [ -z "$output" ]; then
        echo "Error: Both input and output files are required"; return 1
    fi

    local processed_input="$input"
    if grep -q '\\begin{tikzpicture}' "$input"; then
        echo "TikZ code detected - preprocessing..."
        processed_input="${input%.tex}_processed.tex"
        
        python3 - <<'PYTHON_SCRIPT' "$input" "$processed_input"
import sys
import re
import hashlib
import os
import subprocess

def find_balanced(text, start_index):
    count = 0
    for i in range(text.find('{', start_index), len(text)):
        if text[i] == '{': count += 1
        elif text[i] == '}': count -= 1
        if count == 0: return i + 1
    return None

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r') as f:
    content = f.read()

# 1. Extract Global Styles (Libraries and TikZsets)
libraries = "\n".join(re.findall(r'\\usetikzlibrary\{.*?\}', content, re.DOTALL))
tikzsets = []
search_pos = 0
while True:
    match = re.search(r'\\tikzset', content[search_pos:])
    if not match: break
    end = find_balanced(content, search_pos + match.start())
    if end:
        tikzsets.append(content[search_pos + match.start():end])
        search_pos = end
    else: search_pos += 7
shared_styles = libraries + "\n" + "\n".join(tikzsets)

# 2. Find and Replace TikZ pictures
tikz_pattern = r'\\begin{tikzpicture}.*?\\end{tikzpicture}'
matches = list(re.finditer(tikz_pattern, content, re.DOTALL))

for match in reversed(matches):
    tikz_code = match.group(0)
    
    # Use SHA1 hash for a clean filename
    img_hash = hashlib.sha1(tikz_code.encode()).hexdigest()[:16]
    img_name = f"tikz_{img_hash}.png"
    
    if not os.path.exists(img_name):
        tex_content = f"""\\documentclass{{standalone}}
\\usepackage{{tikz}}
\\usetikzlibrary{{positioning,backgrounds,arrows.meta,calc}}
{shared_styles}
\\begin{{document}}
{tikz_code}
\\end{{document}}"""
        
        base_name = img_name[:-4]
        with open(f"{base_name}.tex", 'w') as f: f.write(tex_content)
        
        subprocess.run(['pdflatex', '-interaction=batchmode', f"{base_name}.tex"], stdout=subprocess.DEVNULL)
        subprocess.run(['convert', '-density', '300', f"{base_name}.pdf", img_name], stdout=subprocess.DEVNULL)
        
        for ext in ['.tex', '.pdf', '.log', '.aux']:
            try: os.remove(f"{base_name}{ext}")
            except: pass
    
    # SIMPLE REPLACEMENT (Keep original structure for Titleblock/Filters)
    content = content[:match.start()] + f"\\includegraphics{{{img_name}}}" + content[match.end():]

with open(output_file, 'w') as f:
    f.write(content)
PYTHON_SCRIPT
    fi
    
    local cmd=(pandoc "$processed_input" --filter pandoc-crossref)
    [ -f "zotero.bib" ] && cmd+=(--bibliography=zotero.bib)
    [ -f "packages.bib" ] && cmd+=(--bibliography=packages.bib)
    
    cmd+=(--lua-filter refsection-bibliographies.lua
        -csl global-ecology-and-biogeography.csl
        --lua-filter fix-inner-parens.lua
        --lua-filter fix-titleblock.lua)
    
    [ "$use_move_figures" = true ] && cmd+=(--lua-filter move-figures.lua)
    cmd+=(--reference-doc=latex7.dotx -o "$output")
    
    "${cmd[@]}"
    local exit_code=$?
    
    [ "$processed_input" != "$input" ] && rm -f "$processed_input"
    
    if [ $exit_code -eq 0 ]; then
        rm -f tikz_*.png
        echo "Conversion successful!"
    else
        echo "Error: Pandoc conversion failed"; return 1
    fi
}
