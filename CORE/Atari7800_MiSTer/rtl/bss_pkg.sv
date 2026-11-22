// MiSTer2MEGA65 (Atari 7800 port), November 2026: the 2600 bank switching enum, moved here from detect2600.sv where it was declared at
// compilation-unit ($unit) scope; Vivado project mode does not guarantee that detect2600.sv is compiled
// before cart2600.sv. Users import the package.

package bss_pkg;

typedef enum bit[4:0] {
	BANK00, BANKF8, BANKF6, BANKFE, BANKE0, BANK3F, BANKF4, BANKP2,
	BANKFA, BANKCV, BANK2K, BANKUA, BANKE7, BANKF0, BANK32, BANKAR,
	BANK3E, BANKSB, BANKWD, BANKEF, BANKDPCP, BANKCTY, BANKCDF, BANKEND
} bss_type ;

endpackage
