#!/usr/bin/env python3
"""
Extract tables from JPG images using OCR

This script attempts to extract tabulated data from the 1959 paper images
and convert them to CSV format.
"""

import os
import sys
from pathlib import Path

# First, let's try with img2table
try:
    from img2table.document import Image
    from img2table.ocr import TesseractOCR
    HAS_IMG2TABLE = True
except (ImportError, ValueError, Exception) as e:
    print(f"Warning: img2table not available ({e})")
    HAS_IMG2TABLE = False

# Alternative: try with pytesseract directly
try:
    import pytesseract
    from PIL import Image as PILImage
    HAS_PYTESSERACT = True
except ImportError:
    print("Warning: pytesseract not available")
    HAS_PYTESSERACT = False

# Alternative: try with easyocr (doesn't require Tesseract)
try:
    import easyocr
    HAS_EASYOCR = True
except ImportError:
    HAS_EASYOCR = False

def extract_with_img2table(image_path, output_dir):
    """Extract tables using img2table"""
    try:
        print(f"Attempting to extract from {image_path} using img2table...")
        
        # Initialize OCR
        ocr = TesseractOCR(lang="eng")
        
        # Load image
        img = Image(src=str(image_path))
        
        # Extract tables
        tables = img.extract_tables(ocr=ocr)
        
        if tables:
            print(f"  Found {len(tables)} table(s)")
            for i, table in enumerate(tables):
                # Convert to DataFrame
                df = table.df
                
                # Save to CSV
                output_name = image_path.stem + f"_table_{i+1}.csv"
                output_path = output_dir / output_name
                df.to_csv(output_path, index=False)
                print(f"  Saved: {output_path}")
                print(f"  Shape: {df.shape}")
                print(f"  Preview:\n{df.head()}\n")
        else:
            print(f"  No tables found in {image_path}")
            
        return True
        
    except Exception as e:
        print(f"  Error with img2table: {e}")
        return False

def extract_with_easyocr(image_path, output_dir):
    """Extract text using EasyOCR (CPU-based, no Tesseract needed)"""
    try:
        print(f"Attempting to extract from {image_path} using EasyOCR...")
        
        # Initialize reader (will download models on first run)
        reader = easyocr.Reader(['en'], gpu=False)
        
        # Read text
        result = reader.readtext(str(image_path))
        
        # Save raw text
        output_name = image_path.stem + "_text.txt"
        output_path = output_dir / output_name
        
        with open(output_path, 'w') as f:
            for detection in result:
                bbox, text, conf = detection
                f.write(f"{text}\n")
        
        print(f"  Saved raw text: {output_path}")
        print(f"  Detected {len(result)} text blocks")
        
        return True
        
    except Exception as e:
        print(f"  Error with EasyOCR: {e}")
        return False

def main():
    # Paths
    image_dir = Path("/home/mh7373/GitRepos/ax1_phase1/2025_11_22_9629766d565b25ccbdecg/images")
    output_dir = Path("/home/mh7373/GitRepos/ax1_phase1/extracted_tables")
    output_dir.mkdir(exist_ok=True)
    
    # Images that likely contain tables (based on typical paper structure)
    # Pages 38-42 usually contain results tables in academic papers
    target_images = [
        "2025_11_22_9629766d565b25ccbdecg-038.jpg",
        "2025_11_22_9629766d565b25ccbdecg-039.jpg",
        "2025_11_22_9629766d565b25ccbdecg-040.jpg",
        "2025_11_22_9629766d565b25ccbdecg-041.jpg",
        "2025_11_22_9629766d565b25ccbdecg-042.jpg",
        # Also try some earlier pages
        "2025_11_22_9629766d565b25ccbdecg-027.jpg",
        "2025_11_22_9629766d565b25ccbdecg-028.jpg",
        "2025_11_22_9629766d565b25ccbdecg-029.jpg",
        "2025_11_22_9629766d565b25ccbdecg-030.jpg",
    ]
    
    print("="*70)
    print("TABLE EXTRACTION FROM 1959 PAPER IMAGES")
    print("="*70)
    print()
    
    # Check what's available
    print("Available OCR tools:")
    print(f"  - img2table: {HAS_IMG2TABLE}")
    print(f"  - pytesseract: {HAS_PYTESSERACT}")
    print(f"  - easyocr: {HAS_EASYOCR}")
    print()
    
    if not (HAS_IMG2TABLE or HAS_EASYOCR):
        print("ERROR: No OCR tools available!")
        print()
        print("To install EasyOCR (doesn't require Tesseract):")
        print("  pip install easyocr")
        print()
        print("Or to use img2table:")
        print("  1. Install tesseract: sudo apt-get install tesseract-ocr")
        print("  2. pip install img2table")
        return
    
    # Process images
    success_count = 0
    for img_name in target_images:
        img_path = image_dir / img_name
        
        if not img_path.exists():
            print(f"Skipping {img_name} (not found)")
            continue
        
        print(f"\n{'='*70}")
        print(f"Processing: {img_name}")
        print(f"{'='*70}")
        
        # Try img2table first (better for tables)
        if HAS_IMG2TABLE:
            if extract_with_img2table(img_path, output_dir):
                success_count += 1
                continue
        
        # Fall back to EasyOCR (better compatibility, but less structured)
        if HAS_EASYOCR:
            if extract_with_easyocr(img_path, output_dir):
                success_count += 1
                continue
        
        print(f"  Could not extract from {img_name}")
    
    print()
    print("="*70)
    print(f"EXTRACTION COMPLETE: {success_count}/{len(target_images)} images processed")
    print(f"Output directory: {output_dir}")
    print("="*70)

if __name__ == "__main__":
    main()

