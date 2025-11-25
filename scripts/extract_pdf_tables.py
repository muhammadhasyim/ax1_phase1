#!/usr/bin/env python3
"""
Extract tables from PDF pages 88-100 of the 1959 AX-1 paper

This script converts the PDF pages to images and uses img2table + OCR
to extract the tabulated Geneve 10 data.
"""

import sys
from pathlib import Path

# Check dependencies
try:
    from pdf2image import convert_from_path
    print("✓ pdf2image available")
except ImportError:
    print("✗ pdf2image not available - install with: pip install pdf2image")
    sys.exit(1)

try:
    from PIL import Image as PILImage
    print("✓ PIL available")
except ImportError:
    print("✗ PIL not available")
    sys.exit(1)

# Try img2table (may not work due to numpy issue)
try:
    from img2table.document import Image as ImgDoc
    from img2table.ocr import TesseractOCR
    HAS_IMG2TABLE = True
    print("✓ img2table available")
except Exception as e:
    HAS_IMG2TABLE = False
    print(f"✗ img2table not available: {e}")

# Fallback to EasyOCR
try:
    import easyocr
    import re
    HAS_EASYOCR = True
    print("✓ easyocr available")
except ImportError:
    HAS_EASYOCR = False
    print("✗ easyocr not available")

def extract_with_img2table(image_path, output_dir, page_num):
    """Extract tables using img2table"""
    try:
        print(f"  Using img2table on page {page_num}...")
        
        # Initialize OCR
        ocr = TesseractOCR(lang="eng")
        
        # Load image
        img_doc = ImgDoc(src=str(image_path))
        
        # Extract tables
        tables = img_doc.extract_tables(ocr=ocr)
        
        if tables:
            print(f"    Found {len(tables)} table(s)")
            for i, table in enumerate(tables):
                df = table.df
                output_name = f"page_{page_num}_table_{i+1}.csv"
                output_path = output_dir / output_name
                df.to_csv(output_path, index=False)
                print(f"    Saved: {output_name} (shape: {df.shape})")
            return True
        else:
            print(f"    No tables found")
            return False
            
    except Exception as e:
        print(f"    Error: {e}")
        return False

def extract_with_easyocr(image_path, output_dir, page_num):
    """Extract text using EasyOCR and attempt to parse as table"""
    try:
        print(f"  Using EasyOCR on page {page_num}...")
        
        # Initialize reader
        reader = easyocr.Reader(['en'], gpu=False, verbose=False)
        
        # Read text with bounding boxes
        result = reader.readtext(str(image_path))
        
        # Save raw text
        text_output = output_dir / f"page_{page_num}_text.txt"
        with open(text_output, 'w') as f:
            for detection in result:
                bbox, text, conf = detection
                f.write(f"{text}\n")
        
        print(f"    Extracted {len(result)} text blocks")
        print(f"    Saved raw text: page_{page_num}_text.txt")
        
        # Try to parse as table (simple heuristic)
        lines = []
        for detection in result:
            bbox, text, conf = detection
            if conf > 0.5:  # Only keep confident detections
                lines.append(text)
        
        # Look for numeric patterns
        table_lines = []
        for line in lines:
            # Check if line contains numbers
            if re.search(r'\d+\.?\d*', line):
                table_lines.append(line)
        
        if table_lines:
            table_output = output_dir / f"page_{page_num}_table_raw.txt"
            with open(table_output, 'w') as f:
                for line in table_lines:
                    f.write(f"{line}\n")
            print(f"    Found {len(table_lines)} potential table lines")
        
        return True
        
    except Exception as e:
        print(f"    Error: {e}")
        return False

def main():
    # Paths
    pdf_path = Path("/home/mh7373/GitRepos/ax1_phase1/mdp-39015078509448-1763785606.pdf")
    output_dir = Path("/home/mh7373/GitRepos/ax1_phase1/extracted_pdf_tables")
    output_dir.mkdir(exist_ok=True)
    
    # Images directory
    images_dir = output_dir / "images"
    images_dir.mkdir(exist_ok=True)
    
    if not pdf_path.exists():
        print(f"ERROR: PDF not found at {pdf_path}")
        return
    
    print("="*70)
    print("EXTRACTING TABLES FROM PDF PAGES 88-100")
    print("="*70)
    print(f"PDF: {pdf_path}")
    print(f"Output: {output_dir}")
    print()
    
    # Convert PDF pages 88-100 to images (0-indexed, so 87-99)
    start_page = 88
    end_page = 100
    
    print(f"Converting PDF pages {start_page}-{end_page} to images (DPI=300)...")
    print("This may take a minute...")
    
    try:
        pages = convert_from_path(
            str(pdf_path),
            dpi=300,
            first_page=start_page,
            last_page=end_page
        )
        print(f"✓ Converted {len(pages)} pages\n")
    except Exception as e:
        print(f"ERROR converting PDF: {e}")
        return
    
    # Process each page
    success_count = 0
    for i, page_img in enumerate(pages):
        page_num = start_page + i
        
        print(f"{'='*70}")
        print(f"Page {page_num}")
        print(f"{'='*70}")
        
        # Save as image
        img_path = images_dir / f"page_{page_num}.jpg"
        page_img.save(str(img_path), "JPEG")
        print(f"  Saved image: {img_path.name}")
        
        # Try img2table first
        if HAS_IMG2TABLE:
            if extract_with_img2table(img_path, output_dir, page_num):
                success_count += 1
                continue
        
        # Fallback to EasyOCR
        if HAS_EASYOCR:
            if extract_with_easyocr(img_path, output_dir, page_num):
                success_count += 1
        
        print()
    
    print("="*70)
    print(f"EXTRACTION COMPLETE")
    print(f"Processed: {len(pages)} pages")
    print(f"Success: {success_count} pages")
    print(f"Output directory: {output_dir}")
    print("="*70)
    print()
    print("Next steps:")
    print("1. Check the extracted CSV/text files in:", output_dir)
    print("2. Manually verify the Geneve 10 time-series data")
    print("3. Compare with existing reference data in validation/reference_data/")

if __name__ == "__main__":
    main()

