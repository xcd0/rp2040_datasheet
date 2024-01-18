# Appendix A: Register Field Types

## Standard types

### RW
The processor can write to this field and read the value back.

### RO
The processor can only read this field.

### WO
The processor can only write to this field.

## Clear types

### SC
This is a single bit that is written to by the processor and then cleared on the next clock cycle. An example use of this
would be a start bit that triggers an event, and then clears again so the event doesn’t keep triggering.

### WC
This is a single bit that is typically set by a piece of hardware and then written to by the processor to clear the bit. The
bit is cleared by writing a 1 , using either a normal write or the clear alias. See Section 2.1.2 for more information about
the clear alias.

### FIFO types
These fields are implementation specific.

### RF
Implementation defined read from the hardware.

### WF
Implementation defined write to the hardware.

### RWF

Implementation defined read from, and write to the hardware.



