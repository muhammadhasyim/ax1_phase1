#!/bin/bash
# Script to install all required LaTeX packages for compiling the 1959 document

echo "Installing required TeX Live packages..."
sudo apt install -y \
    texlive-xetex \
    texlive-fonts-extra \
    texlive-latex-extra \
    texlive-science \
    texlive-lang-chinese \
    texlive-lang-japanese \
    texlive-lang-korean \
    texlive-lang-arabic \
    texlive-lang-indian \
    fonts-noto-cjk \
    fonts-noto-cjk-extra

echo ""
echo "Installation complete! You can now compile the LaTeX document with:"
echo "  cd /home/mh7373/GitRepos/ax1_phase1/2025_11_22_9629766d565b25ccbdecg"
echo "  xelatex 2025_11_22_9629766d565b25ccbdecg.tex"


