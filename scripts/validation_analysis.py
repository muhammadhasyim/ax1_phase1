#!/usr/bin/env python3
"""
Validation Analysis Module for AX-1 1959 Code

This module provides tools for loading, analyzing, and comparing simulation results
against reference data from the 1959 ANL-5977 paper.

Author: Automated Implementation
Date: November 23, 2025
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path
from typing import Tuple, Dict, List, Optional
from scipy import interpolate


class ValidationAnalysis:
    """
    Main class for validation analysis of AX-1 simulation results
    """
    
    def __init__(self, validation_dir: str = "validation"):
        """
        Initialize validation analysis
        
        Args:
            validation_dir: Base directory for validation data
        """
        self.validation_dir = Path(validation_dir)
        self.reference_dir = self.validation_dir / "reference_data"
        self.simulation_dir = self.validation_dir / "simulation_results"
        self.plots_dir = self.validation_dir / "plots"
        
        # Create directories if they don't exist
        for dir_path in [self.simulation_dir, self.plots_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)
    
    def load_reference_time_evolution(self) -> pd.DataFrame:
        """
        Load reference time evolution data from CSV
        
        Returns:
            DataFrame with time history data
        """
        file_path = self.reference_dir / "geneve10_time_evolution.csv"
        df = pd.read_csv(file_path, comment='#')
        return df
    
    def load_reference_spatial(self) -> pd.DataFrame:
        """
        Load reference spatial profile data from CSV
        
        Returns:
            DataFrame with spatial profile data at t=200 microsec
        """
        file_path = self.reference_dir / "geneve10_spatial_t200.csv"
        df = pd.read_csv(file_path, comment='#')
        return df
    
    def load_reference_parameters(self) -> pd.DataFrame:
        """
        Load reference input parameters from CSV
        
        Returns:
            DataFrame with all input parameters
        """
        file_path = self.reference_dir / "geneve10_input_parameters.csv"
        df = pd.read_csv(file_path, comment='#')
        return df
    
    def load_simulation_time_evolution(self, filename: str = "ax1_output.csv") -> pd.DataFrame:
        """
        Load simulation time evolution data
        
        Args:
            filename: Name of simulation output file
            
        Returns:
            DataFrame with simulation time history
        """
        file_path = Path(filename)
        if not file_path.exists():
            raise FileNotFoundError(f"Simulation output not found: {file_path}")
        
        df = pd.read_csv(file_path, comment='#')
        return df
    
    def load_simulation_spatial(self, filename: str) -> pd.DataFrame:
        """
        Load simulation spatial profile data
        
        Args:
            filename: Name of spatial profile file
            
        Returns:
            DataFrame with spatial profile data
        """
        file_path = Path(filename)
        if not file_path.exists():
            raise FileNotFoundError(f"Spatial output not found: {file_path}")
        
        df = pd.read_csv(file_path, comment='#')
        return df
    
    def convert_units(self, df: pd.DataFrame, conversions: Dict[str, float]) -> pd.DataFrame:
        """
        Apply unit conversions to DataFrame columns
        
        Args:
            df: Input DataFrame
            conversions: Dictionary mapping column names to conversion factors
            
        Returns:
            DataFrame with converted units
        """
        df_converted = df.copy()
        for col, factor in conversions.items():
            if col in df_converted.columns:
                df_converted[col] = df_converted[col] * factor
        return df_converted
    
    def interpolate_to_common_grid(self, 
                                   ref_data: pd.DataFrame, 
                                   sim_data: pd.DataFrame,
                                   x_col: str = 'time_microsec') -> Tuple[pd.DataFrame, pd.DataFrame]:
        """
        Interpolate reference and simulation data to common grid
        
        Args:
            ref_data: Reference data DataFrame
            sim_data: Simulation data DataFrame
            x_col: Column name for independent variable (time or radius)
            
        Returns:
            Tuple of (interpolated_reference, interpolated_simulation)
        """
        # Find common range
        x_min = max(ref_data[x_col].min(), sim_data[x_col].min())
        x_max = min(ref_data[x_col].max(), sim_data[x_col].max())
        
        # Create common grid
        n_points = min(len(ref_data), len(sim_data), 100)
        x_common = np.linspace(x_min, x_max, n_points)
        
        # Interpolate reference data
        ref_interp = pd.DataFrame({x_col: x_common})
        for col in ref_data.columns:
            if col != x_col and np.issubdtype(ref_data[col].dtype, np.number):
                f = interpolate.interp1d(ref_data[x_col], ref_data[col], 
                                        kind='linear', fill_value='extrapolate')
                ref_interp[col] = f(x_common)
        
        # Interpolate simulation data
        sim_interp = pd.DataFrame({x_col: x_common})
        for col in sim_data.columns:
            if col != x_col and np.issubdtype(sim_data[col].dtype, np.number):
                if col in ref_data.columns:  # Only interpolate matching columns
                    f = interpolate.interp1d(sim_data[x_col], sim_data[col], 
                                            kind='linear', fill_value='extrapolate')
                    sim_interp[col] = f(x_common)
        
        return ref_interp, sim_interp
    
    def calculate_errors(self, 
                        ref_data: pd.DataFrame, 
                        sim_data: pd.DataFrame,
                        columns: List[str]) -> Dict[str, Dict[str, float]]:
        """
        Calculate error metrics between reference and simulation
        
        Args:
            ref_data: Reference data (must be on common grid)
            sim_data: Simulation data (must be on common grid)
            columns: List of column names to compare
            
        Returns:
            Dictionary of error metrics for each column
        """
        errors = {}
        
        for col in columns:
            if col in ref_data.columns and col in sim_data.columns:
                ref_vals = ref_data[col].values
                sim_vals = sim_data[col].values
                
                # Avoid division by zero
                mask = np.abs(ref_vals) > 1e-10
                
                if mask.sum() > 0:
                    # Relative error
                    rel_error = np.abs((sim_vals[mask] - ref_vals[mask]) / ref_vals[mask])
                    
                    # RMS error
                    rms_error = np.sqrt(np.mean((sim_vals[mask] - ref_vals[mask])**2))
                    
                    # Max absolute error
                    max_abs_error = np.max(np.abs(sim_vals[mask] - ref_vals[mask]))
                    
                    errors[col] = {
                        'mean_relative_error': np.mean(rel_error),
                        'max_relative_error': np.max(rel_error),
                        'rms_error': rms_error,
                        'max_absolute_error': max_abs_error,
                        'mean_reference': np.mean(ref_vals[mask]),
                        'mean_simulation': np.mean(sim_vals[mask])
                    }
                else:
                    errors[col] = {
                        'mean_relative_error': np.nan,
                        'max_relative_error': np.nan,
                        'rms_error': np.nan,
                        'max_absolute_error': np.nan,
                        'mean_reference': 0.0,
                        'mean_simulation': 0.0
                    }
        
        return errors
    
    def plot_time_evolution_comparison(self, 
                                      ref_data: pd.DataFrame, 
                                      sim_data: pd.DataFrame,
                                      quantity: str,
                                      ylabel: str,
                                      title: str,
                                      save_name: Optional[str] = None):
        """
        Create comparison plot for time evolution
        
        Args:
            ref_data: Reference data
            sim_data: Simulation data  
            quantity: Column name to plot
            ylabel: Y-axis label
            title: Plot title
            save_name: Optional filename to save plot
        """
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8), 
                                       gridspec_kw={'height_ratios': [3, 1]})
        
        # Main plot
        ax1.plot(ref_data['time_microsec'], ref_data[quantity], 
                'o-', label='Reference (1959)', markersize=6, linewidth=2)
        ax1.plot(sim_data['time_microsec'], sim_data[quantity], 
                's--', label='Simulation', markersize=4, linewidth=1.5, alpha=0.8)
        ax1.set_ylabel(ylabel, fontsize=12)
        ax1.set_title(title, fontsize=14, fontweight='bold')
        ax1.legend(fontsize=11)
        ax1.grid(True, alpha=0.3)
        
        # Error plot
        # Interpolate to common grid for error calculation
        ref_interp, sim_interp = self.interpolate_to_common_grid(
            ref_data, sim_data, 'time_microsec')
        
        mask = np.abs(ref_interp[quantity]) > 1e-10
        rel_error = np.zeros_like(ref_interp[quantity])
        rel_error[mask] = 100 * (sim_interp[quantity][mask] - ref_interp[quantity][mask]) / ref_interp[quantity][mask]
        
        ax2.plot(ref_interp['time_microsec'], rel_error, 'r-', linewidth=1.5)
        ax2.axhline(y=1, color='g', linestyle='--', label='±1% threshold', linewidth=1)
        ax2.axhline(y=-1, color='g', linestyle='--', linewidth=1)
        ax2.axhline(y=0, color='k', linestyle='-', alpha=0.3, linewidth=0.5)
        ax2.set_xlabel('Time (μsec)', fontsize=12)
        ax2.set_ylabel('Relative Error (%)', fontsize=11)
        ax2.legend(fontsize=9)
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        if save_name:
            save_path = self.plots_dir / save_name
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Plot saved: {save_path}")
        
        plt.close()
    
    def plot_spatial_comparison(self, 
                               ref_data: pd.DataFrame, 
                               sim_data: pd.DataFrame,
                               quantity: str,
                               ylabel: str,
                               title: str,
                               save_name: Optional[str] = None):
        """
        Create comparison plot for spatial profiles
        
        Args:
            ref_data: Reference data
            sim_data: Simulation data  
            quantity: Column name to plot
            ylabel: Y-axis label
            title: Plot title
            save_name: Optional filename to save plot
        """
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8),
                                       gridspec_kw={'height_ratios': [3, 1]})
        
        # Main plot
        ax1.plot(ref_data['radius_cm'], ref_data[quantity], 
                'o-', label='Reference (1959)', markersize=6, linewidth=2)
        ax1.plot(sim_data['radius_cm'], sim_data[quantity], 
                's--', label='Simulation', markersize=4, linewidth=1.5, alpha=0.8)
        ax1.set_ylabel(ylabel, fontsize=12)
        ax1.set_title(title, fontsize=14, fontweight='bold')
        ax1.legend(fontsize=11)
        ax1.grid(True, alpha=0.3)
        
        # Error plot
        # Interpolate to common grid for error calculation
        ref_interp, sim_interp = self.interpolate_to_common_grid(
            ref_data, sim_data, 'radius_cm')
        
        mask = np.abs(ref_interp[quantity]) > 1e-10
        rel_error = np.zeros_like(ref_interp[quantity])
        rel_error[mask] = 100 * (sim_interp[quantity][mask] - ref_interp[quantity][mask]) / ref_interp[quantity][mask]
        
        ax2.plot(ref_interp['radius_cm'], rel_error, 'r-', linewidth=1.5)
        ax2.axhline(y=1, color='g', linestyle='--', label='±1% threshold', linewidth=1)
        ax2.axhline(y=-1, color='g', linestyle='--', linewidth=1)
        ax2.axhline(y=0, color='k', linestyle='-', alpha=0.3, linewidth=0.5)
        ax2.set_xlabel('Radius (cm)', fontsize=12)
        ax2.set_ylabel('Relative Error (%)', fontsize=11)
        ax2.legend(fontsize=9)
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        if save_name:
            save_path = self.plots_dir / save_name
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Plot saved: {save_path}")
        
        plt.close()
    
    def generate_error_summary_table(self, errors: Dict[str, Dict[str, float]]) -> pd.DataFrame:
        """
        Generate summary table of error metrics
        
        Args:
            errors: Dictionary of error metrics from calculate_errors()
            
        Returns:
            DataFrame with formatted error summary
        """
        rows = []
        for quantity, metrics in errors.items():
            row = {
                'Quantity': quantity,
                'Mean Rel. Error (%)': f"{metrics['mean_relative_error']*100:.4f}",
                'Max Rel. Error (%)': f"{metrics['max_relative_error']*100:.4f}",
                'RMS Error': f"{metrics['rms_error']:.6e}",
                'Max Abs. Error': f"{metrics['max_absolute_error']:.6e}",
                'Agreement': '✓' if metrics['max_relative_error'] < 0.01 else '✗'
            }
            rows.append(row)
        
        return pd.DataFrame(rows)


def main():
    """
    Example usage of ValidationAnalysis class
    """
    print("=" * 60)
    print("AX-1 Validation Analysis Module")
    print("=" * 60)
    print()
    
    # Initialize analysis
    analysis = ValidationAnalysis()
    
    # Load reference data
    print("Loading reference data...")
    ref_time = analysis.load_reference_time_evolution()
    print(f"  Time evolution: {len(ref_time)} points")
    
    ref_spatial = analysis.load_reference_spatial()
    print(f"  Spatial profile: {len(ref_spatial)} points")
    
    ref_params = analysis.load_reference_parameters()
    print(f"  Input parameters: {len(ref_params)} parameters")
    
    print()
    print("Reference data loaded successfully.")
    print("=" * 60)


if __name__ == "__main__":
    main()

