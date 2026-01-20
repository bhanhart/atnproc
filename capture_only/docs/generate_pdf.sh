#!/usr/bin/env bash

pandoc Design.md -o Design.pdf --number-sections -V geometry:a4paper -V geometry:margin=2cm --pdf-engine=xelatex -V mainfont="DejaVu Serif" -V sansfont="DejaVu Sans" -V fontsize=10pt

