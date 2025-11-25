#!/usr/bin/env python3
"""
Extract tables from PDF using img2table + Tesseract OCR

This script uses the best available tools to extract tabulated data
from pages 88-100 of the 1959 AX-1 paper.
"""

from pathlib import Path
from pdf2image import convert_from_path
from img2table.document import Image as ImgDoc
from img2table.ocr import TesseractOCR
import sys

def main():
    # Paths
    pdf_path = Path("/home/mh7373/GitRepos/ax1_phase1/mdp-39015078509448-1763785606.pdf")
    output_dir = Path("/home/mh7373/GitRepos/ax1_phase1/extracted_pdf_tables_tesseract")
    output_dir.mkdir(exist_ok=True)
    
    # Images directory
    images_dir = output_dir / "images"
    images_dir.mkdir(exist_ok=True)
    
    if not pdf_path.exists():
        print(f"ERROR: PDF not found at {pdf_path}")
        return 1
    
    print("="*80)
    print("EXTRACTING TABLES FROM PDF USING IMG2TABLE + TESSERACT")
    print("="*80)
    print(f"PDF: {pdf_path}")
    print(f"Output: {output_dir}")
    print()
    
    # Initialize OCR
    print("Initializing Tesseract OCR...")
    try:
        ocr = TesseractOCR(lang="eng")
        print("✓ Tesseract OCR initialized\n")
    except Exception as e:
        print(f"✗ Failed to initialize Tesseract: {e}")
        return 1
    
    # Convert PDF pages 88-100 to images
    start_page = 88
    end_page = 100
    
    print(f"Converting PDF pages {start_page}-{end_page} to images (DPI=300)...")
    print("This may take a minute...\n")
    
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
        return 1
    
    # Process each page
    total_tables = 0
    
    for i, page_img in enumerate(pages):
        page_num = start_page + i
        
        print(f"{'='*80}")
        print(f"Processing Page {page_num}")
        print(f"{'='*80}")
        
        # Save as image
        img_path = images_dir / f"page_{page_num}.jpg"
        page_img.save(str(img_path), "JPEG", quality=95)
        print(f"  Saved image: {img_path.name}")
        
        # Extract tables using img2table
        try:
            print(f"  Detecting and extracting tables...")
            img_doc = ImgDoc(src=str(img_path))
            
            # Extract tables
            tables = img_doc.extract_tables(ocr=ocr, implicit_rows=True, borderless_tables=True)
            
            if tables:
                print(f"  ✓ Found {len(tables)} table(s)")
                
                for table_idx, table in enumerate(tables):
                    try:
                        # Convert to DataFrame
                        df = table.df
                        
                        # Save to CSV
                        csv_name = f"page_{page_num}_table_{table_idx+1}.csv"
                        csv_path = output_dir / csv_name
                        df.to_csv(csv_path, index=False)
                        
                        print(f"    Table {table_idx+1}: {df.shape[0]} rows × {df.shape[1]} cols")
                        print(f"    Saved: {csv_name}")
                        
                        # Show preview
                        if df.shape[0] > 0:
                            print(f"    Preview (first 3 rows):")
                            for idx, row in df.head(3).iterrows():
                                print(f"      {list(row.values)}")
                        
                        total_tables += 1
                        
                    except Exception as e:
                        print(f"    ✗ Error processing table {table_idx+1}: {e}")
                
            else:
                print(f"  No tables detected on this page")
                
        except Exception as e:
            print(f"  ✗ Error processing page: {e}")
        
        print()
    
    print("="*80)
    print("EXTRACTION COMPLETE")
    print("="*80)
    print(f"Pages processed: {len(pages)}")
    print(f"Tables extracted: {total_tables}")
    print(f"Output directory: {output_dir}")
    print()
    
    if total_tables > 0:
        print("SUCCESS! 🎉")
        print()
        print("Next steps:")
        print("1. Review the extracted CSV files")
        print("2. Look for Geneve 10 time-series data (TIME, QP, POWER, ALPHA, etc.)")
        print("3. Compare with existing reference data in validation/reference_data/")
    else:
        print("WARNING: No tables were extracted.")
        print("This might mean:")
        print("  - The pages don't contain tables")
        print("  - The tables are in an unusual format")
        print("  - OCR quality is insufficient")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

