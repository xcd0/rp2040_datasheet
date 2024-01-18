

# Chapter 3. PIO

**3.1. Overview**


There are 2 identical PIO blocks in RP2040. Each PIO block has dedicated connections to the bus fabric, GPIO and
interrupt controller. The diagram for a single PIO block is show in Figure 38.

_Figure 38. PIO block-
level diagram. There
are two PIO blocks
with four state
machines each. The
four state machines
simultaneously
execute programs
from a shared
instruction memory.
FIFO data queues
buffer data transferred
between PIO and the
system. GPIO mapping
logic allows each
state machine to
observe and
manipulate up to 30
GPIOs._


The programmable input/output block (PIO) is a versatile hardware interface. It can support a variety of IO standards,
including:

- 8080 and 6800 parallel bus
- I2C
- 3-pin I2S
- SDIO
- SPI, DSPI, QSPI
- UART
- DVI or VGA (via resistor DAC)
PIO is programmable in the same sense as a processor. There are two PIO blocks with four state machines each, that
can independently execute sequential programs to manipulate GPIOs and transfer data. Unlike a general purpose
processor, PIO state machines are highly specialised for IO, with a focus on determinism, precise timing, and close
integration with fixed-function hardware. Each state machine is equipped with:
- Two 32-bit shift registers $2013 either direction, any shift count
- Two 32-bit scratch registers
-^4 ×32-bit bus FIFO in each direction (TX/RX), reconfigurable as 8×32 in a single direction
- Fractional clock divider (16 integer, 8 fractional bits)

3.1. Overview **309**


- Flexible GPIO mapping
- DMA interface, sustained throughput up to 1 word per clock from system DMA
- IRQ flag set/clear/status
Each state machine, along with its supporting hardware, occupies approximately the same silicon area as a standard
serial interface block, such as an SPI or I2C controller. However, PIO state machines can be configured and
reconfigured dynamically to implement numerous different interfaces.


Making state machines programmable in a software-like manner, rather than a fully configurable logic fabric like a
CPLD, allows more hardware interfaces to be offered in the same cost and power envelope. This also presents a more
familiar programming model, and simpler tool flow, to those who wish to exploit PIO’s full flexibility by programming it
directly, rather than using a premade interface from the PIO library.
PIO is highly performant as well as flexible, thanks to a carefully selected set of fixed-function hardware inside each
state machine. When outputting DPI, PIO can sustain 360Mbps during the active scanline period when running from a
48MHz system clock. In this example, one state machine is handling frame/scanline timing and generating the pixel
clock, while another is handling the pixel data, and unpacking run-length-encoded scanlines.
State machines' inputs and outputs are mapped to up to 32 GPIOs (limited to 30 GPIOs for RP2040), and all state
machines have independent, simultaneous access to any GPIO. For example, the standard UART code allows TX, RX,
CTS and RTS to be any four arbitrary GPIOs, and I2C permits the same for SDA and SCL. The amount of freedom
available depends on how exactly a given PIO program chooses to use PIO’s pin mapping resources, but at the
minimum, an interface can be freely shifted up or down by some number of GPIOs.

**3.2. Programmer’s Model**


The four state machines execute from a shared instruction memory. System software loads programs into this memory,
configures the state machines and IO mapping, and then sets the state machines running. PIO programs come from
various sources: assembled directly by the user, drawn from the PIO library, or generated programmatically by user
software.
From this point on, state machines are generally autonomous, and system software interacts through DMA, interrupts
and control registers, as with other peripherals on RP2040. For more complex interfaces, PIO provides a small but
flexible set of primitives which allow system software to be more hands-on with state machine control flow.

_Figure 39. State
machine overview.
Data flows in and out
through a pair of
FIFOs. The state
machine executes a
program which
transfers data
between these FIFOs,
a set of internal
registers, and the pins.
The clock divider can
reduce the state
machine’s execution
speed by a constant
factor._

**3.2.1. PIO Programs**


PIO state machines execute short, binary programs.
Programs for common interfaces, such as UART, SPI, or I2C, are available in the PIO library, so in many cases, it is not
necessary to write PIO programs. However, the PIO is much more flexible when programmed directly, supporting a wide

3.2. Programmer’s Model **310**



variety of interfaces which may not have been foreseen by its designers.
The PIO has a total of nine instructions: JMP, WAIT, IN, OUT, PUSH, PULL, MOV, IRQ, and SET. See Section 3.4 for details on these
instructions.


Though the PIO only has a total of nine instructions, it would be difficult to edit PIO program binaries by hand. PIO
assembly is a textual format, describing a PIO program, where each command corresponds to one instruction in the
output binary. Below is an example program in PIO assembly:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/squarewave/squarewave.pio Lines 7 - 12


$00A07 .program squarewave
$00A08 set pindirs, 1 ; Set pin to output
$00A09 again:
10 set pins, 1 [1] ; Drive pin high and then delay for one cycle
11 set pins, 0 ; Drive pin low
12 jmp again ; Set PC to label `again`


The PIO assembler is included with the SDK, and is called pioasm. This program processes a PIO assembly input text file,
which may contain multiple programs, and writes out the assembled programs ready for use. For the SDK these
assembled programs are emitted in form of C headers, containing constant arrays: For more information see Section
3.3

**3.2.2. Control Flow**


On every system clock cycle, each state machine fetches, decodes and executes one instruction. Each instruction takes
precisely one cycle, unless it explicitly stalls (such as the WAIT instruction). Instructions may also insert a delay of up to
31 cycles before the next instruction is executed to aid the writing of cycle-exact programs.
The program counter, or PC, points to the location in the instruction memory being executed on this cycle. Generally, PC
increments by one each cycle, wrapping at the end of the instruction memory. Jump instructions are an exception and
explicitly provide the next value that PC will take.
Our example assembly program (listed as .program squarewave above) shows both of these concepts in practice. It drives
a 50/50 duty cycle square wave onto a GPIO, with a period of four cycles. Using some other features (e.g. side-set) this
can be made as low as two cycles.

$F05A **NOTE**


Side-set is where a state machine drives a small number of GPIOs in addition to the main side effects of the
instruction it executes. It’s described fully in Section 3.5.1.


The system has write-only access to the instruction memory, which is used to load programs:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/squarewave/squarewave.c Lines 34 - 38


34 // Load the assembled program directly into the PIO's instruction memory.
35 // Each PIO instance has a 32-slot instruction memory, which all 4 state
36 // machines can see. The system has write-only access.
37 for (int i = 0 ; i < count_of(squarewave_program_instructions); ++i)
38 pio->instr_mem[i] = squarewave_program_instructions[i];


The clock divider slows the state machine’s execution by a constant factor, represented as a 16.8 fixed-point fractional
number. Using the above example, if a clock division of 2.5 were programmed, the square wave would have a period of
cycles. This is useful for setting a precise baud rate for a serial interface, such as a UART.

3.2. Programmer’s Model **311**



Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/squarewave/squarewave.c Lines 42 - 47


42 // Configure state machine 0 to run at sysclk/2.5. The state machines can
43 // run as fast as one instruction per clock cycle, but we can scale their
44 // speed down uniformly to meet some precise frequency target, e.g. for a
45 // UART baud rate. This register has 16 integer divisor bits and 8
46 // fractional divisor bits.
47 pio->sm[ 0 ].clkdiv = (uint32_t) ( 2. 5 f * ( 1 << 16 ));


The above code fragments are part of a complete code example which drives a 12.5MHz square wave out of GPIO 0 (or
any other pins we might choose to map). We can also use pins WAIT PIN instruction to stall a state machine’s execution
for some amount of time, or a JMP PIN instruction to branch on the state of a pin, so control flow can vary based on pin
state.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/squarewave/squarewave.c Lines 51 - 59


51 // There are five pin mapping groups (out, in, set, side-set, jmp pin)
52 // which are used by different instructions or in different circumstances.
53 // Here we're just using SET instructions. Configure state machine 0 SETs
54 // to affect GPIO 0 only; then configure GPIO0 to be controlled by PIO0,
55 // as opposed to e.g. the processors.
56 pio->sm[ 0 ].pinctrl =
57 ( 1 << PIO_SM0_PINCTRL_SET_COUNT_LSB) |
58 ( 0 << PIO_SM0_PINCTRL_SET_BASE_LSB);
59 gpio_set_function( 0 , GPIO_FUNC_PIO0);


The system can start and stop each state machine at any time, via the CTRL register. Multiple state machines can be
started simultaneously, and the deterministic nature of PIO means they can stay perfectly synchronised.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/squarewave/squarewave.c Lines 63 - 67


63 // Set the state machine running. The PIO CTRL register is global within a
64 // PIO instance, so you can start/stop multiple state machines
65 // simultaneously. We're using the register's hardware atomic set alias to
66 // make one bit high without doing a read-modify-write on the register.
67 hw_set_bits(&pio->ctrl, 1 << (PIO_CTRL_SM_ENABLE_LSB + 0 ));


Most instructions are executed from the instruction memory, but there are other sources, which can be freely mixed:

- Instructions written to a special configuration register (SMx INSTR) are immediately executed, momentarily
    interrupting other execution. For example, a JMP instruction written to SMx INSTR will cause the state machine to start
    executing from a different location.
- Instructions can be executed from a register, using the MOV EXEC instruction.
- Instructions can be executed from the output shifter, using the OUT EXEC instruction
The last of these is particularly versatile: instructions can be embedded in the stream of data passing through the FIFO.
The I2C example uses this to embed e.g. STOP and RESTART line conditions alongside normal data. In the case of MOV and
OUT EXEC, the MOV/OUT itself executes in one cycle, and the executee on the next.

**3.2.3. Registers**


Each state machine possesses a small number of internal registers. These hold input or output data, and temporary
values such as loop counter variables.

3.2. Programmer’s Model **312**


**3.2.3.1. Output Shift Register (OSR)**

_Figure 40. Output Shift
Register (OSR). Data is
parcelled out 1...32
bits at a time, and
unused data is
recycled by a
bidirectional shifter.
Once empty, the OSR
is reloaded from the
TX FIFO._


The Output Shift Register (OSR) holds and shifts output data, between the TX FIFO and the pins (or other destinations,
such as the scratch registers).

- PULL instructions: remove a 32-bit word from the TX FIFO and place into the OSR.
- OUT instructions shift data from the OSR to other destinations, 1...32 bits at a time.
- The OSR fills with zeroes as data is shifted out
- The state machine will automatically refill the OSR from the FIFO on an OUT instruction, once some total shift count
    threshold is reached, if autopull is enabled
- Shift direction can be left/right, configurable by the processor via configuration registers
For example, to stream data through the FIFO and output to the pins at a rate of one byte per two clocks:


1 .program pull_example1
2 loop:
3 out pins, 8
4 public entry_point:
5 pull
6 out pins, 8 [1]
7 out pins, 8 [1]
8 out pins, 8
9 jmp loop


Autopull (see Section 3.5.4) allows the hardware to automatically refill the OSR in the majority of cases, with the state
machine stalling if it tries to OUT from an empty OSR. This has two benefits:

- No instructions spent on explicitly pulling from FIFO at the right time
- Higher throughput: can output up to 32 bits on every single clock cycle, if the FIFO stays topped up
After configuring autopull, the above program can be simplified to the following, which behaves identically:


1 .program pull_example2
2
3 loop:
4 out pins, 8
5 public entry_point:
6 jmp loop


Program wrapping (Section 3.5.2) allows further simplification and, if desired, an output of 1 byte every system clock
cycle.


1 .program pull_example3
2
3 public entry_point:
4 .wrap_target
5 out pins, 8 [1]
6 .wrap

3.2. Programmer’s Model **313**


**3.2.3.2. Input Shift Register (ISR)**

_Figure 41. Input Shift
Register (ISR). Data
enters 1...32 bits at a
time, and current
contents is shifted left
or right to make room.
Once full, contents is
written to the RX FIFO._

- IN instructions shift 1...32 bits at a time into the register.
- PUSH instructions write the ISR contents to the RX FIFO.
- The ISR is cleared to all-zeroes when pushed.
- The state machine will automatically push the ISR on an IN instruction, once some shift threshold is reached, if
    autopush is enabled.
- Shift direction is configurable by the processor via configuration registers
Some peripherals, like UARTs, must shift in from the left to get correct bit order, since the wire order is LSB-first;
however, the processor may expect the resulting byte to be right-aligned. This is solved by the special null input source,
which allows the programmer to shift some number of zeroes into the ISR, following the data.

**3.2.3.3. Shift Counters**


State machines remember how many bits, in total, have been shifted out of the OSR via OUT instructions, and into the ISR
via IN instructions. This information is tracked at all times by a pair of hardware counters $2014 the output shift counter and
the input shift counter $2014 each capable of holding values from 0 to 32 inclusive. With each shift operation, the relevant
counter is incremented by the shift count, up to the maximum value of 32 (equal to the width of the shift register). The
state machine can be configured to perform certain actions when a counter reaches a configurable threshold:

- The OSR can be automatically refilled once some number of bits have been shifted out. See Section 3.5.4
- The ISR can be automatically emptied once some number of bits have been shifted in. See Section 3.5.4
- PUSH or PULL instructions can be conditioned on the input or output shift counter, respectively
On PIO reset, or the assertion of CTRL_SM_RESTART, the input shift counter is cleared to 0 (nothing yet shifted in), and the
output shift counter is initialised to 32 (nothing remaining to be shifted out; fully exhausted). Some other instructions
affect the shift counters:
- A successful PULL clears the output shift counter to 0
- A successful PUSH clears the input shift counter to 0
- MOV OSR, ... (i.e. any MOV instruction that writes OSR) clears the output shift counter to 0
- MOV ISR, ... (i.e. any MOV instruction that writes ISR) clears the input shift counter to 0
- OUT ISR, count sets the input shift counter to count

**3.2.3.4. Scratch Registers**


Each state machine has two 32-bit internal scratch registers, called X and Y.
They are used as:

- Source/destination for IN/OUT/SET/MOV
- Source for branch conditions
For example, suppose we wanted to produce a long pulse for "1" data bits, and a short pulse for "0" data bits:

3.2. Programmer’s Model **314**



$00A01 .program ws2812_led
$00A02
$00A03 public entry_point:
$00A04 pull
$00A05 set x, 23 ; Loop over 24 bits
$00A06 bitloop:
$00A07 set pins, 1 ; Drive pin high
$00A08 out y, 1 [5] ; Shift 1 bit out, and write it to y
$00A09 jmp !y skip ; Skip the extra delay if the bit was 0
10 nop [5]
11 skip:
12 set pins, 0 [5]
13 jmp x-- bitloop ; Jump if x nonzero, and decrement x
14 jmp entry_point


Here X is used as a loop counter, and Y is used as a temporary variable for branching on single bits from the OSR. This
program can be used to drive a WS2812 LED interface, although more compact implementations are possible (as few
as 3 instructions).
MOV allows the use of the scratch registers to save/restore the shift registers if, for example, you would like to repeatedly
shift out the same sequence.

$F05A **NOTE**


A much more compact WS2812 example (4 instructions total) is shown in Section 3.6.2

**3.2.3.5. FIFOs**


Each state machine has a pair of 4-word deep FIFOs, one for data transfer from system to state machine (TX), and the
other for state machine to system (RX). The TX FIFO is written to by system busmasters, such as a processor or DMA
controller, and the RX FIFO is written to by the state machine. FIFOs decouple the timing of the PIO state machines and
the system bus, allowing state machines to go for longer periods without processor intervention.


FIFOs also generate data request (DREQ) signals, which allow a system DMA controller to pace its reads/writes based
on the presence of data in an RX FIFO, or space for new data in a TX FIFO. This allows a processor to set up a long
transaction, potentially involving many kilobytes of data, which will proceed with no further processor intervention.


Often, a state machine is only transferring data in one direction. In this case the SHIFTCTRL_FJOIN option can merge the
two FIFOs into a single 8-entry FIFO going in one direction only. This is useful for high-bandwidth interfaces such as DPI.

**3.2.4. Stalling**


State machines may momentarily pause execution for a number of reasons:

- A WAIT instruction’s condition is not yet met
- A blocking PULL when the TX FIFO is empty, or a blocking PUSH when the RX FIFO is full
- An IRQ WAIT instruction which has set an IRQ flag, and is waiting for it to clear
- An OUT instruction when autopull is enabled, and OSR has already reached its shift threshold
- An IN instruction when autopush is enabled, ISR reaches its shift threshold, and the RX FIFO is full
In this case, the program counter does not advance, and the state machine will continue executing this instruction on
the next cycle. If the instruction specifies some number of delay cycles before the next instruction starts, these do not
begin until **after** the stall clears.

3.2. Programmer’s Model **315**


$F05A **NOTE**


Side-set (Section 3.5.1) is not affected by stalls, and always takes place on the first cycle of the attached instruction.

**3.2.5. Pin Mapping**


PIO controls the output level and direction of up to 32 GPIOs, and can observe their input levels. On every system clock
cycle, each state machine may do none, one, or both of the following:

- Change the level or direction of some GPIOs via an OUT or SET instruction, or read some GPIOs via an IN instruction
- Change the level or direction of some GPIOs via a side-set operation
Each of these operations is on one of four contiguous ranges of GPIOs, with the base and count of each range
configured via each state machine’s PINCTRL register. There is a range for each of OUT, SET, IN and side-set operations.
Each range can cover any of the GPIOs accessible to a given PIO block (on RP2040 this is the 30 user GPIOs), and the
ranges can overlap.


For each individual GPIO output (level and direction separately), PIO considers all 8 writes that may have occurred on
that cycle, and applies the write from the highest-numbered state machine. If the same state machine performs a SET
/OUT and a side-set on the same GPIO simultaneously, the side-set is used. If no state machine writes to this GPIO
output, its value does not change from the previous cycle.
Generally each state machine’s outputs are mapped to a distinct group of GPIOs, implementing some peripheral
interface.

**3.2.6. IRQ Flags**


IRQ flags are state bits which can be set or cleared by state machines or the system. There are 8 in total: all 8 are visible
to all state machines, and the lower 4 can also be masked into one of PIO’s interrupt request lines, via the IRQ0_INTE and
IRQ1_INTE control registers.


They have two main uses:

- Asserting system level interrupts from a state machine program, and optionally waiting for the interrupt to be
    acknowledged
- Synchronising execution between two state machines
State machines interact with the flags via the IRQ and WAIT instructions.

**3.2.7. Interactions Between State Machines**


The instruction memory is implemented as a 1-write 4-read register file, so all four state machines can read an
instruction on the same cycle, without stalling.
There are three ways to apply the multiple state machines:

- Pointing multiple state machines at the same program
- Pointing multiple state machines at different programs
- Using multiple state machines to run different parts of the same interface, e.g. TX and RX side of a UART, or
    clock/hsync and pixel data on a DPI display
State machines can not communicate data, but they can synchronise with one another by using the IRQ flags. There are
8 flags total (the lower four of which can be masked for use as system IRQs), and each state machine can set or clear
any flag using the IRQ instruction, and can wait for a flag to go high or low using the WAIT IRQ instruction. This allows
cycle-accurate synchronisation between state machines.

3.2. Programmer’s Model **316**


**3.3. PIO Assembler (pioasm)**


The PIO Assembler parses a PIO source file and outputs the assembled version ready for inclusion in an RP2040
application. This includes C and C++ applications built against the SDK, and Python programs running on the RP2040
MicroPython port.
This section briefly introduces the directives and instructions that can be used in pioasm input. A deeper discussion of
how to use pioasm, how it is integrated into the SDK build system, extended features such as code pass through, and the
various output formats it can produce, is given in the Raspberry Pi Pico C/C++ SDK book.

**3.3.1. Directives**


The following directives control the assembly of PIO programs:

_Table 362. pioasm
directives .define_ ( _PUBLIC_ ) _<symbol> <value>_ Define an integer symbol named _<symbol>_ with the value _<value>_ (see Section
3.3.2). If this _.define_ appears before the first program in the input file, then the
define is global to all programs, otherwise it is local to the program in which it
occurs. If _PUBLIC_ is specified the symbol will be emitted into the assembled
output for use by user code. For the SDK this takes the form of:


#define <program_name>_<symbol> value for program symbols or #define <symbol>
value for global symbols


.program <name> Start a new program with the name <name>. Note that that name is used in
code so should be alphanumeric/underscore not starting with a digit. The
program lasts until another .program directive or the end of the source file. PIO
instructions are only allowed within a program


.origin <offset> Optional directive to specify the PIO instruction memory offset at which the
program must load. Most commonly this is used for programs that must load
at offset 0, because they use data based JMPs with the (absolute) jmp target
being stored in only a few bits. This directive is invalid outside of a program


.side_set <count> (opt) (pindirs) If this directive is present, <count> indicates the number of side-set bits to be
used. Additionally opt may be specified to indicate that a side <value> is
optional for instructions (note this requires stealing an extra bit $2014 in addition
to the <count> bits $2014 from those available for the instruction delay). Finally,
pindirs may be specified to indicate that the side set values should be applied
to the PINDIRs and not the PINs. This directive is only valid within a program
before the first instruction


.wrap_target Place prior to an instruction, this directive specifies the instruction where
execution continues due to program wrapping. This directive is invalid outside
of a program, may only be used once within a program, and if not specified
defaults to the start of the program


.wrap Placed after an instruction, this directive specifies the instruction after which,
in normal control flow (i.e. jmp with false condition, or no jmp), the program
wraps (to .wrap_target instruction). This directive is invalid outside of a
program, may only be used once within a program, and if not specified
defaults to after the last program instruction.


.lang_opt <lang> <name> <option> Specifies an option for the program related to a particular language generator.
(See Language generators). This directive is invalid outside of a program


.word <value> Stores a raw 16-bit value as an instruction in the program. This directive is
invalid outside of a program.

3.3. PIO Assembler (pioasm) **317**


**3.3.2. Values**


The following types of values can be used to define integer numbers or branch targets

_Table 363. Values in
pioasm, i.e. <value> integer_ An integer value e.g. 3 or -7


hex A hexadecimal value e.g. 0xf


binary A binary value e.g. 0b1001


symbol A value defined by a .define (see [pioasm_define])


<label> The instruction offset of the label within the program. This makes most sense when used with
a JMP instruction (see Section 3.4.2)


( <expression> ) An expression to be evaluated; see expressions. Note that the parentheses are necessary.

**3.3.3. Expressions**


Expressions may be freely used within pioasm values.

_Table 364.
Expressions in pioasm
i.e. <expression>_


<expression> + <expression> The sum of two expressions
<expression> - <expression> The difference of two expressions


<expression> * <expression> The multiplication of two expressions


<expression> / <expression> The integer division of two expressions

_- <expression>_ The negation of another expression
_:: <expression>_ The bit reverse of another expression


<value> Any value (see Section 3.3.2)

**3.3.4. Comments**


Line comments are supported with // or ;
C-style block comments are supported via /* and */

**3.3.5. Labels**


Labels are of the form:
<symbol>:
or
PUBLIC <symbol>:
at the start of a line.

3.3. PIO Assembler (pioasm) **318**


$F0EB **TIP**


A label is really just an automatic .define with a value set to the current program instruction offset. A PUBLIC label is
exposed to the user code in the same way as a PUBLIC .define.

**3.3.6. Instructions**


All pioasm instructions follow a common pattern:
<instruction> ( side <side_set_value> ) ( [<delay_value>] )


where:


<instruction> Is an assembly instruction detailed in the following sections. (See Section 3.4)


<side_set_value> Is a value (see Section 3.3.2) to apply to the side_set pins at the start of the instruction. Note that
the rules for a side-set value via side <side_set_value> are dependent on the .side_set (see
[pioasm_side_set]) directive for the program. If no .side_set is specified then the side
<side_set_value> is invalid, if an optional number of sideset pins is specified then side
<side_set_value> may be present, and if a non-optional number of sideset pins is specified, then
side <side_set_value> is required. The <side_set_value> must fit within the number of side-set bits
specified in the .side_set directive.


<delay_value> Specifies the number of cycles to delay after the instruction completes. The delay_value is
specified as a value (see Section 3.3.2), and in general is between 0 and 31 inclusive (a 5-bit
value), however the number of bits is reduced when sideset is enabled via the .side_set (see
[pioasm_side_set]) directive. If the <delay_value> is not present, then the instruction has no delay

$F05A **NOTE**


pioasm instruction names, keywords and directives are case insensitive; lower case is used in the Assembly Syntax
sections below as this is the style used in the SDK.

$F05A **NOTE**


Commas appear in some Assembly Syntax sections below, but are entirely optional, e.g. out pins, 3 may be written
out pins 3, and jmp x-- label may be written as jmp x--, label. The Assembly Syntax sections below uses the first
style in each case as this is the style used in the SDK.

**3.3.7. Pseudoinstructions**


Currently pioasm provides one pseudoinstruction, as a convenience:


nop Assembles to mov y, y. "No operation", has no particular side effect, but a useful vehicle for a side-set
operation or an extra delay.

**3.4. Instruction Set**

**3.4.1. Summary**


PIO instructions are 16 bits long, and have the following encoding:

3.4. Instruction Set **319**


_Table 365. PIO
instruction encoding_
**Bit: 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0**


JMP 0 0 0 Delay/side-set Condition Address
WAIT 0 0 1 Delay/side-set Pol Source Index


IN 0 1 0 Delay/side-set Source Bit count


OUT 0 1 1 Delay/side-set Destination Bit count


PUSH 1 0 0 Delay/side-set 0 IfF Blk 0 0 0 0 0


PULL 1 0 0 Delay/side-set 1 IfE Blk 0 0 0 0 0
MOV 1 0 1 Delay/side-set Destination Op Source


IRQ 1 1 0 Delay/side-set 0 Clr Wait Index


SET 1 1 1 Delay/side-set Destination Data


All PIO instructions execute in one clock cycle.
The function of the 5-bit Delay/side-set field depends on the state machine’s SIDESET_COUNT configuration:

- Up to 5 LSBs (5 minus SIDESET_COUNT) encode a number of idle cycles inserted between this instruction and the next.
- Up to 5 MSBs, set by SIDESET_COUNT, encode a side-set (Section 3.5.1), which can assert a constant onto some
    GPIOs, concurrently with main instruction execution.

**3.4.2. JMP**

**3.4.2.1. Encoding**


Bit: 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
JMP 0 0 0 Delay/side-set Condition Address

**3.4.2.2. Operation**


Set program counter to Address if Condition is true, otherwise no operation.


Delay cycles on a JMP always take effect, whether Condition is true or false, and they take place after Condition is
evaluated and the program counter is updated.

- Condition:

	- 000: _(no condition)_ : Always


	- 001: !X: scratch X zero
	- 010: X--: scratch X non-zero, prior to decrement
	- 011: !Y: scratch Y zero


	- 100: Y--: scratch Y non-zero, prior to decrement
	- 101: X!=Y: scratch X not equal scratch Y
	- 110: PIN: branch on input pin

	- 111: !OSRE: output shift register not empty

- Address: Instruction address to jump to. In the instruction encoding this is an absolute address within the PIO
    instruction memory.

3.4. Instruction Set **320**



JMP PIN branches on the GPIO selected by EXECCTRL_JMP_PIN, a configuration field which selects one out of the maximum
of 32 GPIO inputs visible to a state machine, independently of the state machine’s other input mapping. The branch is
taken if the GPIO is high.


!OSRE compares the bits shifted out since the last PULL with the shift count threshold configured by SHIFTCTRL_PULL_THRESH.
This is the same threshold used by autopull (Section 3.5.4).
JMP X-- and JMP Y-- always decrement scratch register X or Y, respectively. The decrement is not conditional on the
current value of the scratch register. The branch is conditioned on the initial value of the register, i.e. before the
decrement took place: if the register is initially nonzero, the branch is taken.

**3.4.2.3. Assembler Syntax**


jmp ( <cond> ) <target>


where:


<cond> Is an optional condition listed above (e.g. !x for scratch X zero). If a condition code is not specified,
the branch is always taken


<target> Is a program label or value (see Section 3.3.2) representing instruction offset within the program (the
first instruction being offset 0). Note that because the PIO JMP instruction uses absolute addresses
in the PIO instruction memory, JMPs need to be adjusted based on the program load offset at
runtime. This is handled for you when loading a program with the SDK, but care should be taken when
encoding JMP instructions for use by OUT EXEC

**3.4.3. WAIT**

**3.4.3.1. Encoding**


Bit: 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
WAIT 0 0 1 Delay/side-set Pol Source Index

**3.4.3.2. Operation**


Stall until some condition is met.
Like all stalling instructions (Section 3.2.4), delay cycles begin after the instruction completes. That is, if any delay
cycles are present, they do not begin counting until after the wait condition is met.

- Polarity:

	- 1: wait for a 1.

	- 0: wait for a 0.

- Source: what to wait on. Values are:


	- 00: GPIO: System GPIO input selected by Index. This is an absolute GPIO index, and is not affected by the state
machine’s input IO mapping.


	- 01: PIN: Input pin selected by Index. This state machine’s input IO mapping is applied first, and then Index
selects which of the mapped bits to wait on. In other words, the pin is selected by adding Index to the
PINCTRL_IN_BASE configuration, modulo 32.

	- 10: IRQ: PIO IRQ flag selected by Index

3.4. Instruction Set **321**


	- 11: Reserved

- Index: which pin or bit to check.
WAIT x IRQ behaves slightly differently from other WAIT sources:
- If Polarity is 1, the selected IRQ flag is cleared by the state machine upon the wait condition being met.
- The flag index is decoded in the same way as the IRQ index field: if the MSB is set, the state machine ID (0...3) is
added to the IRQ index, by way of modulo-4 addition on the two LSBs. For example, state machine 2 with a flag
value of '0x11' will wait on flag 3, and a flag value of '0x13' will wait on flag 1. This allows multiple state machines
running the same program to synchronise with each other.

$F071 **CAUTION**


WAIT 1 IRQ x should not be used with IRQ flags presented to the interrupt controller, to avoid a race condition with a
system interrupt handler

**3.4.3.3. Assembler Syntax**


wait <polarity> gpio <gpio_num>
wait <polarity> pin <pin_num>


wait <polarity> irq <irq_num> ( rel )
where:


<polarity> Is a value (see Section 3.3.2) specifying the polarity (either 0 or 1)


<pin_num> Is a value (see Section 3.3.2) specifying the input pin number (as mapped by the SM input pin
mapping)
<gpio_num> Is a value (see Section 3.3.2) specifying the actual GPIO pin number


<irq_num> ( rel ) Is a value (see Section 3.3.2) specifying The irq number to wait on (0-7). If rel is present, then the
actual irq number used is calculating by replacing the low two bits of the irq number ( irq_num 10 )
with the low two bits of the sum ( irq_num 10 + sm_num 10 ) where sm_num 10 is the state machine
number

**3.4.4. IN**

**3.4.4.1. Encoding**


Bit: 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
IN 0 1 0 Delay/side-set Source Bit count

**3.4.4.2. Operation**


Shift Bit count bits from Source into the Input Shift Register (ISR). Shift direction is configured for each state machine by
SHIFTCTRL_IN_SHIFTDIR. Additionally, increase the input shift count by Bit count, saturating at 32.

- Source:

	- 000: PINS

	- 001: X (scratch register X)

3.4. Instruction Set **322**



	- 010: Y (scratch register Y)
	- 011: NULL (all zeroes)


	- 100: Reserved
	- 101: Reserved
	- 110: ISR

	- 111: OSR

- Bit count: How many bits to shift into the ISR. 1...32 bits, 32 is encoded as^00000.
If automatic push is enabled, IN will also push the ISR contents to the RX FIFO if the push threshold is reached
(SHIFTCTRL_PUSH_THRESH). IN still executes in one cycle, whether an automatic push takes place or not. The state machine
will stall if the RX FIFO is full when an automatic push occurs. An automatic push clears the ISR contents to all-zeroes,
and clears the input shift count. See Section 3.5.4.


IN always uses the least significant Bit count bits of the source data. For example, if PINCTRL_IN_BASE is set to 5, the
instruction IN PINS, 3 will take the values of pins 5, 6 and 7, and shift these into the ISR. First the ISR is shifted to the left
or right to make room for the new input data, then the input data is copied into the gap this leaves. The bit order of the
input data is not dependent on the shift direction.
NULL can be used for shifting the ISR’s contents. For example, UARTs receive the LSB first, so must shift to the right.
After 8 IN PINS, 1 instructions, the input serial data will occupy bits 31...24 of the ISR. An IN NULL, 24 instruction will shift
in 24 zero bits, aligning the input data at ISR bits 7...0. Alternatively, the processor or DMA could perform a byte read
from FIFO address + 3, which would take bits 31...24 of the FIFO contents.

**3.4.4.3. Assembler Syntax**


in <source>, <bit_count>


where:


<source> Is one of the sources specified above.


<bit_count> Is a value (see Section 3.3.2) specifying the number of bits to shift (valid range 1-32)

**3.4.5. OUT**

**3.4.5.1. Encoding**


Bit: 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
OUT 0 1 1 Delay/side-set Destination Bit count

**3.4.5.2. Operation**


Shift Bit count bits out of the Output Shift Register (OSR), and write those bits to Destination. Additionally, increase the
output shift count by Bit count, saturating at 32.

- Destination:


	- 000: PINS
	- 001: X (scratch register X)

	- 010: Y (scratch register Y)

3.4. Instruction Set **323**



	- 011: NULL (discard data)
	- 100: PINDIRS


	- 101: PC
	- 110: ISR (also sets ISR shift counter to Bit count)
	- 111: EXEC (Execute OSR shift data as instruction)

- Bit count: how many bits to shift out of the OSR. 1...32 bits, 32 is encoded as^00000.
A 32-bit value is written to Destination: the lower Bit count bits come from the OSR, and the remainder are zeroes. This
value is the least significant Bit count bits of the OSR if SHIFTCTRL_OUT_SHIFTDIR is to the right, otherwise it is the most
significant bits.
PINS and PINDIRS use the OUT pin mapping, as described in Section 3.5.6.
If automatic pull is enabled, the OSR is automatically refilled from the TX FIFO if the pull threshold, SHIFTCTRL_PULL_THRESH,
is reached. The output shift count is simultaneously cleared to 0. In this case, the OUT will stall if the TX FIFO is empty,
but otherwise still executes in one cycle. The specifics are given in Section 3.5.4.


OUT EXEC allows instructions to be included inline in the FIFO datastream. The OUT itself executes on one cycle, and the
instruction from the OSR is executed on the next cycle. There are no restrictions on the types of instructions which can
be executed by this mechanism. Delay cycles on the initial OUT are ignored, but the executee may insert delay cycles as
normal.
OUT PC behaves as an unconditional jump to an address shifted out from the OSR.

**3.4.5.3. Assembler Syntax**


out <destination>, <bit_count>
where:


<destination> Is one of the destinations specified above.


<bit_count> Is a value (see Section 3.3.2) specifying the number of bits to shift (valid range 1-32)

**3.4.6. PUSH**

**3.4.6.1. Encoding**


Bit: 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0


PUSH 1 0 0 Delay/side-set 0 IfF Blk 0 0 0 0 0

**3.4.6.2. Operation**


Push the contents of the ISR into the RX FIFO, as a single 32-bit word. Clear ISR to all-zeroes.

- IfFull: If 1, do nothing unless the total input shift count has reached its threshold, SHIFTCTRL_PUSH_THRESH (the same
    as for autopush; see Section 3.5.4).
- Block: If 1, stall execution if RX FIFO is full.
PUSH IFFULL helps to make programs more compact, like autopush. It is useful in cases where the IN would stall at an
inappropriate time if autopush were enabled, e.g. if the state machine is asserting some external control signal at this
point.

3.4. Instruction Set **324**



The PIO assembler sets the Block bit by default. If the Block bit is not set, the PUSH does not stall on a full RX FIFO, instead
continuing immediately to the next instruction. The FIFO state and contents are unchanged when this happens. The ISR
is still cleared to all-zeroes, and the FDEBUG_RXSTALL flag is set (the same as a blocking PUSH or autopush to a full RX FIFO)
to indicate data was lost.

**3.4.6.3. Assembler Syntax**


push ( iffull )
push ( iffull ) block
push ( iffull ) noblock


where:


iffull Is equivalent to IfFull == 1 above. i.e. the default if this is not specified is IfFull == 0


block Is equivalent to Block == 1 above. This is the default if neither block nor noblock are specified


noblock Is equivalent to Block == 0 above.

**3.4.7. PULL**

**3.4.7.1. Encoding**


Bit: 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
PULL 1 0 0 Delay/side-set 1 IfE Blk 0 0 0 0 0

**3.4.7.2. Operation**


Load a 32-bit word from the TX FIFO into the OSR.

- IfEmpty: If 1, do nothing unless the total output shift count has reached its threshold, SHIFTCTRL_PULL_THRESH (the
    same as for autopull; see Section 3.5.4).
- Block: If 1, stall if TX FIFO is empty. If 0, pulling from an empty FIFO copies scratch X to OSR.
Some peripherals (UART, SPI...) should halt when no data is available, and pick it up as it comes in; others (I2S) should
clock continuously, and it is better to output placeholder or repeated data than to stop clocking. This can be achieved
with the Block parameter.


A nonblocking PULL on an empty FIFO has the same effect as MOV OSR, X. The program can either preload scratch register
X with a suitable default, or execute a MOV X, OSR after each PULL NOBLOCK, so that the last valid FIFO word will be recycled
until new data is available.
PULL IFEMPTY is useful if an OUT with autopull would stall in an inappropriate location when the TX FIFO is empty. IfEmpty
permits some of the same program simplifications as autopull $2014 for example, the elimination of an outer loop
counter $2014 but the stall occurs at a controlled point in the program.

3.4. Instruction Set **325**


$F05A **NOTE**


When autopull is enabled, any PULL instruction is a no-op when the OSR is full, so that the PULL instruction behaves as
a barrier. OUT NULL, 32 can be used to explicitly discard the OSR contents. See Section 3.5.4.2 for more detail.

**3.4.7.3. Assembler Syntax**


pull ( ifempty )
pull ( ifempty ) block


pull ( ifempty ) noblock
where:


ifempty Is equivalent to IfEmpty == 1 above. i.e. the default if this is not specified is IfEmpty == 0


block Is equivalent to Block == 1 above. This is the default if neither block nor noblock are specified


noblock Is equivalent to Block == 0 above.

**3.4.8. MOV**

**3.4.8.1. Encoding**


Bit: 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
MOV 1 0 1 Delay/side-set Destination Op Source

**3.4.8.2. Operation**


Copy data from Source to Destination.

- Destination:

	- 000: PINS (Uses same pin mapping as OUT)


	- 001: X (Scratch register X)
	- 010: Y (Scratch register Y)


	- 011: Reserved
	- 100: EXEC (Execute data as instruction)
	- 101: PC


	- 110: ISR (Input shift counter is reset to 0 by this operation, i.e. empty)
	- 111: OSR (Output shift counter is reset to 0 by this operation, i.e. full)

- Operation:


	- 00: None
	- 01: Invert (bitwise complement)


	- 10: Bit-reverse
	- 11: Reserved

3.4. Instruction Set **326**


- Source:

	- 000: PINS (Uses same pin mapping as IN)


	- 001: X
	- 010: Y
	- 011: NULL


	- 100: Reserved
	- 101: STATUS


	- 110: ISR
	- 111: OSR
MOV PC causes an unconditional jump. MOV EXEC has the same behaviour as OUT EXEC (Section 3.4.5), and allows register
contents to be executed as an instruction. The MOV itself executes in 1 cycle, and the instruction in Source on the next
cycle. Delay cycles on MOV EXEC are ignored, but the executee may insert delay cycles as normal.
The STATUS source has a value of all-ones or all-zeroes, depending on some state machine status such as FIFO
full/empty, configured by EXECCTRL_STATUS_SEL.
MOV can manipulate the transferred data in limited ways, specified by the Operation argument. Invert sets each bit in
Destination to the logical NOT of the corresponding bit in Source, i.e. 1 bits become 0 bits, and vice versa. Bit reverse sets
each bit n in Destination to bit 31 - n in Source, assuming the bits are numbered 0 to 31.
MOV dst, PINS reads pins using the IN pin mapping, and writes the full 32-bit value to the destination without masking.
The LSB of the read value is the pin indicated by PINCTRL_IN_BASE, and each successive bit comes from a higher-
numbered pin, wrapping after 31.

**3.4.8.3. Assembler Syntax**


mov <destination>, ( op ) <source>
where:


<destination> Is one of the destinations specified above.
<op> If present, is:


! or ~ for NOT (Note: this is always a bitwise NOT)


:: for bit reverse


<source> Is one of the sources specified above.

**3.4.9. IRQ**

**3.4.9.1. Encoding**


Bit: 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
IRQ 1 1 0 Delay/side-set 0 Clr Wait Index

3.4. Instruction Set **327**


**3.4.9.2. Operation**


Set or clear the IRQ flag selected by Index argument.

- Clear: if 1, clear the flag selected by Index, instead of raising it. If Clear is set, the Wait bit has no effect.
- Wait: if 1, halt until the raised flag is lowered again, e.g. if a system interrupt handler has acknowledged the flag.
- Index:


	- The 3 LSBs specify an IRQ index from 0-7. This IRQ flag will be set/cleared depending on the Clear bit.
	- If the MSB is set, the state machine ID (0...3) is added to the IRQ index, by way of modulo-4 addition on the
two LSBs. For example, state machine 2 with a flag value of 0x11 will raise flag 3, and a flag value of 0x13 will
raise flag 1.
IRQ flags 4-7 are visible only to the state machines; IRQ flags 0-3 can be routed out to system level interrupts, on either
of the PIO’s two external interrupt request lines, configured by IRQ0_INTE and IRQ1_INTE.
The modulo addition bit allows relative addressing of 'IRQ' and 'WAIT' instructions, for synchronising state machines
which are running the same program. Bit 2 (the third LSB) is unaffected by this addition.


If Wait is set, Delay cycles do not begin until after the wait period elapses.

**3.4.9.3. Assembler Syntax**


irq <irq_num> ( rel )
irq set <irq_num> ( rel )
irq nowait <irq_num> ( rel )


irq wait <irq_num> ( rel )
irq clear <irq_num> ( rel )


where:


<irq_num> ( rel ) Is a value (see Section 3.3.2) specifying The irq number to wait on (0-7). If rel is present, then the
actual irq number used is calculating by replacing the low two bits of the irq number ( irq_num 10 )
with the low two bits of the sum ( irq_num 10 + sm_num 10 ) where sm_num 10 is the state machine
number


irq Means set the IRQ without waiting


irq set Also means set the IRQ without waiting
irq nowait Again, means set the IRQ without waiting


irq wait Means set the IRQ and wait for it to be cleared before proceeding


irq clear Means clear the IRQ

**3.4.10. SET**

**3.4.10.1. Encoding**


Bit: 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
SET 1 1 1 Delay/side-set Destination Data

3.4. Instruction Set **328**


**3.4.10.2. Operation**


Write immediate value Data to Destination.

- Destination:

	- 000: PINS


	- 001: X (scratch register X) 5 LSBs are set to Data, all others cleared to 0.
	- 010: Y (scratch register Y) 5 LSBs are set to Data, all others cleared to 0.
	- 011: Reserved


	- 100: PINDIRS
	- 101: Reserved
	- 110: Reserved

	- 111: Reserved

- Data: 5-bit immediate value to drive to pins or register.
This can be used to assert control signals such as a clock or chip select, or to initialise loop counters. As Data is 5 bits in
size, scratch registers can be SET to values from 0-31, which is sufficient for a 32-iteration loop.
The mapping of SET and OUT onto pins is configured independently. They may be mapped to distinct locations, for
example if one pin is to be used as a clock signal, and another for data. They may also be overlapping ranges of pins: a
UART transmitter might use SET to assert start and stop bits, and OUT instructions to shift out FIFO data to the same pins.

**3.4.10.3. Assembler Syntax**


set <destination>, <value>
where:


<destination> Is one of the destinations specified above.
<value> The value (see Section 3.3.2) to set (valid range 0-31)

**3.5. Functional Details**

**3.5.1. Side-set**


Side-set is a feature that allows state machines to change the level or direction of up to 5 pins, concurrently with the
main execution of the instruction.


One example where this is necessary is a fast SPI interface: here a clock transition (toggling 1→0 or 0→1) must be
simultaneous with a data transition, where a new data bit is shifted from the OSR to a GPIO. In this case an OUT with a
side-set would achieve both of these at once.


This makes the timing of the interface more precise, reduces the overall program size (as a separate SET instruction is
not needed to toggle the clock pin), and also increases the maximum frequency the SPI can run at.


Side-set also makes GPIO mapping much more flexible, as its mapping is independent from SET. The example I2C code
allows SDA and SCL to be mapped to any two arbitrary pins, if clock stretching is disabled. Normally, SCL toggles to
synchronise data transfer, and SDA contains the data bits being shifted out. However, some particular I2C sequences
such as Start and Stop line conditions, need a fixed pattern to be driven on SDA as well as SCL. The mapping I2C uses to
achieve this is:

3.5. Functional Details **329**


- Side-set → SCL
- OUT^ → SDA
- SET^ → SDA
This lets the state machine serve the two use cases of data on SDA and clock on SCL, or fixed transitions on both SDA
and SCL, while still allowing SDA and SCL to be mapped to any two GPIOs of choice.


The side-set data is encoded in the Delay/side-set field of each instruction. Any instruction can be combined with side-
set, including instructions which write to the pins, such as OUT PINS or SET PINS. Side-set’s pin mapping is independent
from OUT and SET mappings, though it may overlap. If side-set and an OUT or SET write to the same pin simultaneously, the
side-set data is used.

$F05A **NOTE**


If an instruction stalls, the side-set still takes effect immediately.


1 .program spi_tx_fast
2 .side_set 1
3
4 loop:
5 out pins, 1 side 0
6 jmp loop side 1


The spi_tx_fast example shows two benefits of this: data and clock transitions can be more precisely co-aligned, and
programs can be made faster overall, with an output of one bit per two system clock cycles in this case. Programs can
also be made smaller.
There are four things to configure when using side-set:


1.The number of MSBs of the Delay/side-set field to use for side-set rather than delay. This is configured by
PINCTRL_SIDESET_COUNT. If this is set to 5, delay cycles are not available. If set to 0, no side-set will take place.
2.Whether to use the most significant of these bits as an enable. Side-set takes place on instructions where the
enable is high. If there is no enable bit, every instruction on that state machine will perform a side-set, if
SIDESET_COUNT is nonzero. This is configured by EXECCTRL_SIDE_EN.


3.The GPIO number to map the least-significant side-set bit to. Configured by PINCTRL_SIDESET_BASE.
4.Whether side-set writes to GPIO levels or GPIO directions. Configured by EXECCTRL_SIDE_PINDIR
In the above example, we have only one side-set data bit, and every instruction performs a side-set, so no enable bit is
required. SIDESET_COUNT would be 1, SIDE_EN would be false. SIDE_PINDIR would also be false, as we want to drive the clock
high and low, not high- and low-impedance. SIDESET_BASE would select the GPIO the clock is driven from.

**3.5.2. Program Wrapping**


PIO programs often have an "outer loop": they perform the same sequence of steps, repetitively, as they transfer a
stream of data between the FIFOs and the outside world. The square wave program from the introduction is a minimal
example of this:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/squarewave/squarewave.pio Lines 7 - 12


$00A07 .program squarewave
$00A08 set pindirs, 1 ; Set pin to output
$00A09 again:
10 set pins, 1 [1] ; Drive pin high and then delay for one cycle
11 set pins, 0 ; Drive pin low

3.5. Functional Details **330**



12 jmp again ; Set PC to label `again`


The main body of the program drives a pin high, and then low, producing one period of a square wave. The entire
program then loops, driving a periodic output. The jump itself takes one cycle, as does each set instruction, so to keep
the high and low periods of the same duration, the set pins, 1 has a single delay cycle added, which makes the state
machine idle for one cycle before executing the set pins, 0 instruction. In total, each loop takes four cycles. There are
two frustrations here:

- The JMP takes up space in the instruction memory that could be used for other programs
- The extra cycle taken to execute the JMP ends up _halving_ the maximum output rate
As the Program Counter (PC) naturally wraps to 0 when incremented past 31, we could solve the second of these by
filling the entire instruction memory with a repeating pattern of set pins, 1 and set pins, 0, but this is wasteful. State
machines have a hardware feature, configured via their EXECCTRL control register, which solves this common case.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/squarewave/squarewave_wrap.pio Lines 11 - 19


11 .program squarewave_wrap
12 ; Like squarewave, but use the state machine's .wrap hardware instead of an
13 ; explicit jmp. This is a free (0-cycle) unconditional jump.
14
15 set pindirs, 1 ; Set pin to output
16 .wrap_target
17 set pins, 1 [1] ; Drive pin high and then delay for one cycle
18 set pins, 0 [1] ; Drive pin low and then delay for one cycle
19 .wrap


After executing an instruction from the program memory, state machines use the following logic to update PC:
1.If the current instruction is a JMP, and the Condition is true, set PC to the Target


2.Otherwise, if PC matches EXECCTRL_WRAP_TOP, set PC to EXECCTRL_WRAP_BOTTOM
3.Otherwise, increment PC, or set to 0 if the current value is 31.
The .wrap_target and .wrap assembly directives in pioasm are essentially labels. They export constants which can be
written to the WRAP_BOTTOM and WRAP_TOP control fields, respectively:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/squarewave/generated/squarewave_wrap.pio.h


$00A01 // -------------------------------------------------- //
$00A02 // This file is autogenerated by pioasm; do not edit! //
$00A03 // -------------------------------------------------- //
$00A04
$00A05 #pragma once
$00A06
$00A07 #if !PICO_NO_HARDWARE
$00A08 #include "hardware/pio.h"
$00A09 #endif
10
11 // --------------- //
12 // squarewave_wrap //
13 // --------------- //
14
15 #define squarewave_wrap_wrap_target 1
16 #define squarewave_wrap_wrap 2
17
18 static const uint16_t squarewave_wrap_program_instructions[] = {
19 0xe081, // 0: set pindirs, 1
20 // .wrap_target
21 0xe101, // 1: set pins, 1 [1]

3.5. Functional Details **331**



22 0xe100, // 2: set pins, 0 [1]
23 // .wrap
24 };
25
26 #if !PICO_NO_HARDWARE
27 static const struct pio_program squarewave_wrap_program = {
28 .instructions = squarewave_wrap_program_instructions,
29 .length = 3 ,
30 .origin = - 1 ,
31 };
32
33 static inline pio_sm_config squarewave_wrap_program_get_default_config(uint offset) {
34 pio_sm_config c = pio_get_default_sm_config();
35 sm_config_set_wrap(&c, offset + squarewave_wrap_wrap_target, offset +
squarewave_wrap_wrap);
36 return c;
37 }
38 #endif


This is raw output from the PIO assembler, pioasm, which has created a default pio_sm_config object containing the WRAP
register values from the program listing. The control register fields could also be initialised directly.

$F05A **NOTE**


WRAP_BOTTOM and WRAP_TOP are absolute addresses in the PIO instruction memory. If a program is loaded at an offset,
the wrap addresses must be adjusted accordingly.


The squarewave_wrap example has delay cycles inserted, so that it behaves identically to the original squarewave program.
Thanks to program wrapping, these can now be removed, so that the output toggles twice as fast, while maintaining an
even balance of high and low periods.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/squarewave/squarewave_fast.pio Lines 12 - 18


12 .program squarewave_fast
13 ; Like squarewave_wrap, but remove the delay cycles so we can run twice as fast.
14 set pindirs, 1 ; Set pin to output
15 .wrap_target
16 set pins, 1 ; Drive pin high
17 set pins, 0 ; Drive pin low
18 .wrap

**3.5.3. FIFO Joining**


By default, each state machine possesses a 4-entry FIFO in each direction: one for data transfer from system to state
machine (TX), the other for the reverse direction (RX). However, many applications do not require bidirectional data
transfer between the system and an individual state machine, but may benefit from deeper FIFOs: in particular, high-
bandwidth interfaces such as DPI. For these cases, SHIFTCTRL_FJOIN can merge the two 4-entry FIFOs into a single 8-entry
FIFO.

3.5. Functional Details **332**


_Figure 42. Joinable
dual FIFO. A pair of
four-entry FIFOs,
implemented with four
data registers, a 1:4
decoder and a 4:1
multiplexer. Additional
multiplexing allows
write data and read
data to cross between
the TX and RX lanes,
so that all 8 entries
are accessible from
both ports_


Another example is a UART: because the TX/CTS and RX/RTS parts a of a UART are asynchronous, they are
implemented on two separate state machines. It would be wasteful to leave half of each state machine’s FIFO
resources idle. The ability to join the two halves into just a TX FIFO for the TX/CTS state machine, or just an RX FIFO in
the case of the RX/RTS state machine, allows full utilisation. A UART equipped with an 8-deep FIFO can be left alone for
twice as long between interrupts as one with only a 4-deep FIFO.


When one FIFO is increased in size (from 4 to 8), the other FIFO on that state machine is reduced to zero. For example, if
joining to TX, the RX FIFO is unavailable, and any PUSH instruction will stall. The RX FIFO will appear both RXFULL and
RXEMPTY in the FSTAT register. The converse is true if joining to RX: the TX FIFO is unavailable, and the TXFULL and TXEMPTY
bits for this state machine will both be set in FSTAT. Setting both FJOIN_RX and FJOIN_TX makes both FIFOs unavailable.
8 FIFO entries is sufficient for 1 word per clock through the RP2040 system DMA, provided the DMA is not slowed by
contention with other masters.

$F071 **CAUTION**


Changing FJOIN discards any data present in the state machine’s FIFOs. If this data is irreplaceable, it must be
drained beforehand.

**3.5.4. Autopush and Autopull**


With each OUT instruction, the OSR gradually empties, as data is shifted out. Once empty, it must be refilled: for example,
a PULL transfers one word of data from the TX FIFO to the OSR. Similarly, the ISR must be emptied once full. One
approach to this is a loop which performs a PULL after an appropriate amount of data has been shifted:


$00A01 .program manual_pull
$00A02 .side_set 1 opt
$00A03
$00A04 .wrap_target
$00A05 set x, 2 ; X = bit count - 2
$00A06 pull side 1 [1] ; Stall here if no TX data
$00A07 bitloop:
$00A08 out pins, 1 side 0 [1] ; Shift out data bit and toggle clock low
$00A09 jmp x-- bitloop side 1 [1] ; Loop runs 3 times
10 out pins, 1 side 0 ; Shift out last bit before reloading X
11 .wrap


This program shifts out 4 bits from each FIFO word, with an accompanying bit clock, at a constant rate of 1 bit per 4
cycles. When the TX FIFO is empty, it stalls with the clock high (noting that side-set still takes place on cycles where the

3.5. Functional Details **333**



instruction stalls). Figure 43 shows how a state machine would execute this program.


System Clock


32 0 2 3 4


2 1 0 -1 2


1


Instruction
Scratch X
Clock pin (side -set)
OSR shift count


SET PULL OUT JMP OUT JMP OUT JMP OUT SET PULL


Data pin (OUT) Bit 0 Bit 1 Bit 2 Bit 3

_Figure 43. Execution
of manual_pull
program. X is used as
a loop counter. On
each iteration, one
data bit is shifted out,
and the clock is
asserted low, then
high. A delay cycle on
each instruction
brings the total up to
four cycles per
iteration. After the
third loop, a fourth bit
is shifted out, and the
state machine
immediately returns to
the start of the
program to reload the
loop counter and pull
fresh data, while
maintaining the 4
cycles/bit cadence._


This program has some limitations:

- It occupies 5 instruction slots, but only 2 of these are immediately useful (out pins, 1 set 0 and ... set 1), for
    outputting serial data and a clock.
- Its throughput is limited to system clock over 4, due to the extra cycles required to pull in new data, and reload the
    loop counter
This is a common type of problem for PIO, so each state machine has some extra hardware to handle it. State machines
keep track of the total shift count OUT of the OSR and IN to the ISR, and trigger certain actions once these counters reach
a programmable threshold.
- On an OUT instruction which reaches or exceeds the pull threshold, the state machine can simultaneously refill the
OSR from the TX FIFO, if data is available.
- On an IN instruction which reaches or exceeds the push threshold, the state machine can write the shift result
directly to the RX FIFO, and clear the ISR.
The manual_pull example can be rewritten to take advantage of automatic pull (autopull):


1 .program autopull
2 .side_set 1
3
4 .wrap_target
5 out pins, 1 side 0 [1]
6 nop side 1 [1]
7 .wrap


This is shorter and simpler than the original, and can run twice as fast, if the delay cycles are removed, since the
hardware refills the OSR "for free". Note that the program does not determine the total number of bits to be shifted
before the next pull; the hardware automatically pulls once the programmable threshold, SHIFCTRL_PULL_THRESH, is reached,
so the same program could also shift out e.g. 16 or 32 bits from each FIFO word.
Finally, note that the above program is not exactly the same as the original, since it stalls with the clock output low,
rather than high. We can change the location of the stall, using the PULL IFEMPTY instruction, which uses the same
configurable threshold as autopull:


1 .program somewhat_manual_pull
2 .side_set 1
3
4 .wrap_target
5 out pins, 1 side 0 [1]
6 pull ifempty side 1 [1]
7 .wrap


Below is a complete example (PIO program, plus a C program to load and run it) which illustrates autopull and autopush
both enabled on the same state machine. It programs state machine 0 to loopback data from the TX FIFO to the RX
FIFO, with a throughput of one word per two clocks. It also demonstrates how the state machine will stall if it tries to OUT
when both the OSR and TX FIFO are empty.

3.5. Functional Details **334**



1 .program auto_push_pull
2
3 .wrap_target
4 out x, 32
5 in x, 32
6 .wrap


$00A01 #include "tb.h" // TODO this is built against existing sw tree, so that we get printf etc
$00A02
$00A03 #include "platform.h"
$00A04 #include "pio_regs.h"
$00A05 #include "system.h"
$00A06 #include "hardware.h"
$00A07
$00A08 #include "auto_push_pull.pio.h"
$00A09
10 int main()
11 {
12 tb_init();
13
14 // Load program and configure state machine 0 for autopush/pull with
15 // threshold of 32, and wrapping on program boundary. A threshold of 32 is
16 // encoded by a register value of 00000.
17 for (int i = 0 ; i < count_of(auto_push_pull_program); ++i)
18 mm_pio->instr_mem[i] = auto_push_pull_program[i];
19 mm_pio->sm[ 0 ].shiftctrl =
20 (1u << PIO_SM0_SHIFTCTRL_AUTOPUSH_LSB) |
21 (1u << PIO_SM0_SHIFTCTRL_AUTOPULL_LSB) |
22 (0u << PIO_SM0_SHIFTCTRL_PUSH_THRESH_LSB) |
23 (0u << PIO_SM0_SHIFTCTRL_PULL_THRESH_LSB);
24 mm_pio->sm[ 0 ].execctrl =
25 (auto_push_pull_wrap_target << PIO_SM0_EXECCTRL_WRAP_BOTTOM_LSB) |
26 (auto_push_pull_wrap << PIO_SM0_EXECCTRL_WRAP_TOP_LSB);
27
28 // Start state machine 0
29 hw_set_bits(&mm_pio->ctrl, 1u << (PIO_CTRL_SM_ENABLE_LSB + 0 ));
30
31 // Push data into TX FIFO, and pop from RX FIFO
32 for (int i = 0 ; i < 5 ; ++i)
33 mm_pio->txf[ 0 ] = i;
34 for (int i = 0 ; i < 5 ; ++i)
35 printf("%d\n", mm_pio->rxf[ 0 ]);
36
37 return 0 ;
38 }


Figure 44 shows how the state machine executes the example program. Initially the OSR is empty, so the state machine
stalls on the first OUT instruction. Once data is available in the TX FIFO, the state machine transfers this into the OSR. On
the next cycle, the OUT can execute using the data in the OSR (in this case, transferring this data to the X scratch
register), and the state machine simultaneously refills the OSR with fresh data from the FIFO. Since every IN instruction
immediately fills the ISR, the ISR remains empty, and IN transfers data directly from scratch X to the RX FIFO.

3.5. Functional Details **335**



clock


32 0 0 0 0 0 32


0 0 0 0 0 0
1 2 3 4 5


Current Instruction
Stall
TX FIFO Empty
TX FIFO Pop
OSR Count (0=full)
RX FIFO Push
ISR Count (0=empty)
RX FIFO Push


OUT IN OUT IN OUT IN OUT IN OUT IN OUT

_Figure 44. Execution
of auto_push_pull
program. The state
machine stalls on an
OUT until data has
travelled through the
TX FIFO into the OSR.
Subsequently, the OSR
is refilled
simultaneously with
each OUT operation
(due to bit count of
32), and IN data
bypasses the ISR and
goes straight to the RX
FIFO. The state
machine stalls again
when the FIFO has
drained, and the OSR
is once again empty._


To trigger automatic push or pull at the correct time, the state machine tracks the total shift count of the ISR and OSR,
using a pair of saturating 6-bit counters.

- At reset, or upon CTRL_SM_RESTART assertion, ISR shift counter is set to 0 (nothing shifted in), and OSR to 32 (nothing
    left to be shifted out)
- An OUT instruction increases the OSR shift counter by Bit count
- An IN instruction increases the ISR shift counter by Bit count
- A PULL instruction or autopull clears the OSR counter to 0
- A PUSH instruction or autopush clears the ISR counter to 0
- A MOV OSR, x or MOV ISR, x clears the OSR or ISR shift counter to 0, respectively
- A OUT ISR, n instruction sets the ISR shift counter to n
On any OUT or IN instruction, the state machine compares the shift counters to the values of SHIFTCTRL_PULL_THRESH and
SHIFTCTRL_PUSH_THRESH to decide whether action is required. Autopull and autopush are individually enabled by the
SHIFTCTRL_AUTOPULL and SHIFTCTRL_AUTOPUSH fields.

**3.5.4.1. Autopush Details**


Pseudocode for an 'IN' with autopush enabled:


$00A01 isr = shift_in(isr, input())
$00A02 isr count = saturate(isr count + in count)
$00A03
$00A04 if rx count >= threshold:
$00A05 if rx fifo is full:
$00A06 stall
$00A07 else:
$00A08 push(isr)
$00A09 isr = 0
10 isr count = 0


Note that the hardware performs the above steps in a single machine clock cycle (unless there is a stall).
Threshold is configurable from 1 to 32.

**3.5.4.2. Autopull Details**


On non-'OUT' cycles, the hardware performs the equivalent of the following pseudocode:

3.5. Functional Details **336**



1 if MOV or PULL:
2 osr count = 0
3
4 if osr count >= threshold:
5 if tx fifo not empty:
6 osr = pull()
7 osr count = 0


An autopull can therefore occur at any point between two 'OUT' s, depending on when the data arrives in the FIFO.
On 'OUT' cycles, the sequence is a little different:


$00A01 if osr count >= threshold:
$00A02 if tx fifo not empty:
$00A03 osr = pull()
$00A04 osr count = 0
$00A05 stall
$00A06 else:
$00A07 output(osr)
$00A08 osr = shift(osr, out count)
$00A09 osr count = saturate(osr count + out count)
10
11 if osr count >= threshold:
12 if tx fifo not empty:
13 osr = pull()
14 osr count = 0


The hardware is capable of refilling the OSR simultaneously with shifting out the last of the shift data, as these two
operations can proceed in parallel. However, it cannot fill an empty OSR and 'OUT' it on the same cycle, due to the long
logic path this would create.
The refill is somewhat asynchronous to your program, but an 'OUT' behaves as a data fence, and the state machine will
never 'OUT' data which you didn’t write into the FIFO.
Note that a 'MOV' from the OSR is undefined whilst autopull is enabled; you will read either any residual data that has
not been shifted out, or a fresh word from the FIFO, depending on a race against system DMA. Likewise, a 'MOV' to the
OSR may overwrite data which has just been autopulled. However, data which you 'MOV' into the OSR will never be
overwritten, since 'MOV' updates the shift counter.


If you do need to read the OSR contents, you should perform an explicit 'PULL' of some kind. The nondeterminism
described above is the cost of the hardware managing pulls automatically. When autopull is enabled, the behaviour of
'PULL' is altered: it becomes a no-op if the OSR is full. This is to avoid a race condition against the system DMA. It
behaves as a fence: either an autopull has already taken place, in which case the 'PULL' has no effect, or the program
will stall on the 'PULL' until data becomes available in the FIFO.


'PUSH' does not need a similar behaviour, because autopush does not have the same nondeterminism.

**3.5.5. Clock Dividers**


PIO runs off the system clock, but this is simply too fast for many interfaces, and the number of Delay cycles which can
be inserted is limited. Some devices, such as UART, require the signalling rate to be precisely controlled and varied, and
ideally multiple state machines can be varied independently while running identical programs. Each state machine is
equipped with a clock divider, for this purpose.
Rather than slowing the system clock itself, the clock divider redefines how many system clock periods are considered
to be "one cycle", for execution purposes. It does this by generating a clock enable signal, which can pause and resume
execution on a per-system-clock-cycle basis. The clock divider generates clock enable pulses at regular intervals, so

3.5. Functional Details **337**



that the state machine runs at some steady pace, potentially much slower than the system clock.
Implementing the clock dividers in this way allows interfacing between the state machines and the system to be
simpler, lower-latency, and with a smaller footprint. The state machine is completely idle on cycles where clock enable
is low, though the system can still access the state machine’s FIFOs and change its configuration.
The clock dividers are 16-bit integer, 8-bit fractional, with first-order delta-sigma for the fractional divider. The clock
divisor can vary between 1 and 65536, in increments of.


If the clock divisor is set to 1, the state machine runs on every cycle, i.e. full speed:


System Clock
CLKDIV_INT
CLKDIV_FRAC
Clock Enable


CTRL_SM_ENABLE


1
.0

_Figure 45. State
machine operation
with a clock divisor of_

_1. Once the state
machine is enabled via
the CTRL register, its
clock enable is
asserted on every
cycle._
    In general, an integer clock divisor of _n_ will cause the state machine to run 1 cycle in every _n_ , giving an effective clock
    speed of.


System Clock
CLKDIV_INT
CLKDIV_FRAC
Clock Enable


CTRL_SM_ENABLE


2
.0

_Figure 46. Integer
clock divisors yield a
periodic clock enable.
The clock divider
repeatedly counts
down from n, and
emits an enable pulse
when it reaches 1._ Fractional division will maintain a steady state division rate of , where _n_ and _f_ are the integer and fractional


fields of this state machine’s CLKDIV register. It does this by selectively extending some division periods from cycles to
.


System Clock
CLKDIV_INT
CLKDIV_FRAC
Clock Enable


CTRL_SM_ENABLE


2
.5

_Figure 47. Fractional
clock division with an
average divisor of 2.5.
The clock divider
maintains a running
total of the fractional
value from each
division period, and
every time this value
wraps through 1, the
integer divisor is
increased by one for
the next division
period._


For small n , the jitter introduced by a fractional divider may be unacceptable. However, for larger values, this effect is
much less apparent.

$F05A **NOTE**


For fast asynchronous serial, it is recommended to use even divisions or multiples of 1 Mbaud where possible,
rather than the traditional multiples of 300, to avoid unnecessary jitter.

**3.5.6. GPIO Mapping**


Internally, PIO has a 32-bit register for the output levels of each GPIO it can drive, and another register for the output
enables (Hi/Lo-Z). On every system clock cycle, each state machine can write to some or all of the GPIOs in each of
these registers.

3.5. Functional Details **338**


_Figure 48. The state
machine has two
independent output
channels, one shared
by OUT/SET, and
another used by side-
set (which can happen
at any time). Three
independent mappings
(first GPIO, number of
GPIOs) control which
GPIOs OUT, SET and
side-set are directed
to. Input data is
rotated according to
which GPIO is mapped
to the LSB of the IN
data._


The write data and write masks for the output level and output enable registers come from the following sources:

- An OUT instruction writes to up to 32 bits. Depending on the instruction’s Destination field, this is applied to either
    pins or pindirs. The least-significant bit of OUT data is mapped to PINCTRL_OUT_BASE, and this mapping continues for
    PINCTRL_OUT_COUNT bits, wrapping after GPIO31.
- A SET instruction writes up to 5 bits. Depending on the instruction’s Destination field, this is applied to either pins or
    pindirs. The least-significant bit of SET data is mapped to PINCTRL_SET_BASE, and this mapping continues for
    PINCTRL_SET_COUNT bits, wrapping after GPIO31.
- A side-set operation writes up to 5 bits. Depending on the register field EXECCTRL_SIDE_PINDIR, this is applied to either
    pins or pindirs. The least-significant bit of side-set data is mapped to PINCTRL_SIDESET_BASE, continuing for
    PINCTRL_SIDESET_COUNT pins, minus one if EXECCTRL_SIDE_EN is set.
Each OUT/SET/side-set operation writes to a contiguous range of pins, but each of these ranges is independently sized
and positioned in the 32-bit GPIO space. This is sufficiently flexible for many applications. For example, if one state
machine is implementing some interface such as an SPI on a group of pins, another state machine can run the same
program, mapped to a different group of pins, and provide a second SPI interface.
On any given clock cycle, the state machine may perform an OUT or a SET, and may simultaneously perform a side-set.
The pin mapping logic generates a 32-bit write mask and write data bus for the output level and output enable registers,
based on this request, and the pin mapping configuration.
If a side-set overlaps with an OUT/SET performed by that state machine on the same cycle, the side-set takes precedence
in the overlapping region.

**3.5.6.1. Output Priority**

_Figure 49. Per-GPIO
priority select of write
masks from each
state machine. Each
GPIO considers level
and direction writes
from each of the four
state machines, and
applies the value from
the highest-numbered
state machine._


Each state machine may assert an OUT/SET and a side-set through its pin mapping hardware on each cycle. This
generates 32 bits of write data and write mask for the GPIO output level and output enable registers, from each state
machine.


For each GPIO, PIO collates the writes from all four state machines, and applies the write from the highest-numbered

3.5. Functional Details **339**



state machine. This occurs separately for output levels and output values $2014 it is possible for a state machine to change
both the level and direction of the same pin on the same cycle (e.g. via simultaneous SET and side-set), or for one state
machine to change a GPIO’s direction while another changes that GPIO’s level. If no state machine asserts a write to a
GPIO’s level or direction, the value does not change.

**3.5.6.2. Input Mapping**


The data observed by IN instructions is mapped such that the LSB is the GPIO selected by PINCTRL_IN_BASE, and
successively more-significant bits come from successively higher-numbered GPIOs, wrapping after 31.
In other words, the IN bus is a right-rotate of the GPIO input values, by PINCTRL_IN_BASE. If fewer than 32 GPIOs are
present, the PIO input is padded with zeroes up to 32 bits.
Some instructions, such as WAIT GPIO, use an absolute GPIO number, rather than an index into the IN data bus. In this
case, the right-rotate is not applied.

**3.5.6.3. Input Synchronisers**


To protect PIO from metastabilities, each GPIO input is equipped with a standard 2-flipflop synchroniser. This adds two
cycles of latency to input sampling, but the benefit is that state machines can perform an IN PINS at any point, and will
see only a clean high or low level, not some intermediate value that could disturb the state machine circuitry. This is
absolutely necessary for asynchronous interfaces such as UART RX.
It is possible to bypass these synchronisers, on a per-GPIO basis. This reduces input latency, but it is then up to the user
to guarantee that the state machine does not sample its inputs at inappropriate times. Generally this is only possible for
synchronous interfaces such as SPI. Synchronisers are bypassed by setting the corresponding bit in INPUT_SYNC_BYPASS.

$F056 **WARNING**


Sampling a metastable input can lead to unpredictable state machine behaviour. This should be avoided.

**3.5.7. Forced and EXEC’d Instructions**


Besides the instruction memory, state machines can execute instructions from 3 other sources:

- MOV EXEC which executes an instruction from some register Source
- OUT EXEC which executes data shifted out from the OSR
- The SMx_INSTR control registers, to which the system can write instructions for immediate execution


$00A01 .program exec_example
$00A02
$00A03 hang:
$00A04 jmp hang
$00A05 execute:
$00A06 out exec, 32
$00A07 jmp execute
$00A08
$00A09 .program instructions_to_push
10
11 out x, 32
12 in x, 32
13 push

3.5. Functional Details **340**



$00A01 #include "tb.h" // TODO this is built against existing sw tree, so that we get printf etc
$00A02
$00A03 #include "platform.h"
$00A04 #include "pio_regs.h"
$00A05 #include "system.h"
$00A06 #include "hardware.h"
$00A07
$00A08 #include "exec_example.pio.h"
$00A09
10 int main()
11 {
12 tb_init();
13
14 for (int i = 0 ; i < count_of(exec_example_program); ++i)
15 mm_pio->instr_mem[i] = exec_example_program[i];
16
17 // Enable autopull, threshold of 32
18 mm_pio->sm[ 0 ].shiftctrl = (1u << PIO_SM0_SHIFTCTRL_AUTOPULL_LSB);
19
20 // Start state machine 0 -- will sit in "hang" loop
21 hw_set_bits(&mm_pio->ctrl, 1u << (PIO_CTRL_SM_ENABLE_LSB + 0 ));
22
23 // Force a jump to program location 1
24 mm_pio->sm[ 0 ].instr = 0x0000 | 0x1; // jmp execute
25
26 // Feed a mixture of instructions and data into FIFO
27 mm_pio->txf[ 0 ] = instructions_to_push_program[ 0 ]; // out x, 32
28 mm_pio->txf[ 0 ] = 12345678 ; // data to be OUTed
29 mm_pio->txf[ 0 ] = instructions_to_push_program[ 1 ]; // in x, 32
30 mm_pio->txf[ 0 ] = instructions_to_push_program[ 2 ]; // push
31
32 // The program pushed into TX FIFO will return some data in RX FIFO
33 while (mm_pio->fstat & (1u << PIO_FSTAT_RXEMPTY_LSB))
34 ;
35
36 printf("%d\n", mm_pio->rxf[ 0 ]);
37
38 return 0 ;
39 }


Here we load an example program into the state machine, which does two things:

- Enters an infinite loop
- Enters a loop which repeatedly pulls 32 bits of data from the TX FIFO, and executes the lower 16 bits as an
    instruction
The C program sets the state machine running, at which point it enters the hang loop. While the state machine is still
running, the C program forces in a jmp instruction, which causes the state machine to break out of the loop.
When an instruction is written to the INSTR register, the state machine immediately decodes and executes that
instruction, rather than the instruction it would have fetched from the PIO’s instruction memory. The program counter
does not advance, so on the next cycle (assuming the instruction forced into the INSTR interface did not stall) the state
machine continues to execute its current program from the point where it left off, unless the written instruction itself
manipulated PC.
Delay cycles are ignored on instructions written to the INSTR register, and execute immediately, ignoring the state
machine clock divider. This interface is provided for performing initial setup and effecting control flow changes, so it
executes instructions in a timely manner, no matter how the state machine is configured.
Instructions written to the INSTR register are permitted to stall, in which case the state machine will latch this instruction
internally until it completes. This is signified by the EXECCTRL_EXEC_STALLED flag. This can be cleared by restarting the state

3.5. Functional Details **341**



machine, or writing a NOP to INSTR.
In the second phase of the example state machine program, the OUT EXEC instruction is used. The OUT itself occupies one
execution cycle, and the instruction which the OUT executes is on the next execution cycle. Note that one of the
instructions we execute is also an OUT $2014 the state machine is only capable of executing one OUT instruction on any given
cycle.
OUT EXEC works by writing the OUT shift data to an internal instruction latch. On the next cycle, the state machine
remembers it must execute from this latch rather than the instruction memory, and also knows to not advance PC on this
second cycle.


This program will print "12345678" when run.

$F071 **CAUTION**


If an instruction written to INSTR stalls, it is stored in the same instruction latch used by OUT EXEC and MOV EXEC, and will
overwrite an in-progress instruction there. If EXEC instructions are used, instructions written to INSTR must not stall.

**3.6. Examples**


These examples illustrate some of PIO’s hardware features, by implementing common I/O interfaces.


Looking to get started?


The Raspberry Pi Pico C/C++ SDK book has a comprehensive PIO chapter, which walks through writing
and building a first PIO application, and goes on to walk through some programs line-by-line. It also
covers broader topics such as using PIO with DMA, and goes into much more depth on how PIO can be
integrated into your software.

**3.6.1. Duplex SPI**

3.6. Examples **342**


_Figure 50. In SPI, a
host and device
exchange data over a
bidirectional pair of
serial data lines,
synchronous with a
clock (SCK). Two
flags, CPOL and
CPHA, specify the
clock’s behaviour.
CPOL is the idle state
of the clock: 0 for low,
1 for high. The clock
pulses a number of
times, transferring one
bit in each direction
per pulse, but always
returns to its idle
state. CPHA
determines on which
edge of the clock data
is captured: 0 for
leading edge, and 1 for
trailing edge. The
arrows in the figure
show the clock edge
where data is captured
by both the host and
device._


SPI is a common serial interface with a twisty history. The following program implements full-duplex (i.e. transferring
data in both directions simultaneously) SPI, with a CPHA parameter of 0.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/spi/spi.pio Lines 14 - 32


14 .program spi_cpha0
15 .side_set 1
16
17 ; Pin assignments:
18 ; - SCK is side-set pin 0
19 ; - MOSI is OUT pin 0
20 ; - MISO is IN pin 0
21 ;
22 ; Autopush and autopull must be enabled, and the serial frame size is set by
23 ; configuring the push/pull threshold. Shift left/right is fine, but you must
24 ; justify the data yourself. This is done most conveniently for frame sizes of
25 ; 8 or 16 bits by using the narrow store replication and narrow load byte
26 ; picking behaviour of RP2040's IO fabric.
27
28 ; Clock phase = 0: data is captured on the leading edge of each SCK pulse, and
29 ; transitions on the trailing edge, or some time before the first leading edge.
30
31 out pins, 1 side 0 [1] ; Stall here on empty (sideset proceeds even if
32 in pins, 1 side 1 [1] ; instruction stalls, so we stall with SCK low)


This code uses autopush and autopull to continuously stream data from the FIFOs. The entire program runs once for
every bit that is transferred, and then loops. The state machine tracks how many bits have been shifted in/out, and
automatically pushes/pulls the FIFOs at the correct point. A similar program handles the CPHA=1 case:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/spi/spi.pio Lines 34 - 42


34 .program spi_cpha1
35 .side_set 1
36
37 ; Clock phase = 1: data transitions on the leading edge of each SCK pulse, and
38 ; is captured on the trailing edge.
39
40 out x, 1 side 0 ; Stall here on empty (keep SCK deasserted)
41 mov pins, x side 1 [1] ; Output data, assert SCK (mov pins uses OUT mapping)
42 in pins, 1 side 0 ; Input data, deassert SCK

3.6. Examples **343**


$F05A **NOTE**


These programs do not control the chip select line; chip select is often implemented as a software-controlled GPIO,
due to wildly different behaviour between different SPI hardware. The full spi.pio source linked above contains some
examples how PIO can implement a hardware chip select line.


A C helper function configures the state machine, connects the GPIOs, and sets the state machine running. Note that
the SPI frame size $2014 that is, the number of bits transferred for each FIFO record $2014 can be programmed to any value
from 1 to 32, without modifying the program. Once configured, the state machine is set running.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/spi/spi.pio Lines 46 - 72


46 static inline void pio_spi_init(PIO pio, uint sm, uint prog_offs, uint n_bits,
47 float clkdiv, bool cpha, bool cpol, uint pin_sck, uint pin_mosi, uint pin_miso) {
48 pio_sm_config c = cpha? spi_cpha1_program_get_default_config(prog_offs) :
spi_cpha0_program_get_default_config(prog_offs);
49 sm_config_set_out_pins(&c, pin_mosi, 1 );
50 sm_config_set_in_pins(&c, pin_miso);
51 sm_config_set_sideset_pins(&c, pin_sck);
52 // Only support MSB-first in this example code (shift to left, auto push/pull,
threshold=nbits)
53 sm_config_set_out_shift(&c, false, true, n_bits);
54 sm_config_set_in_shift(&c, false, true, n_bits);
55 sm_config_set_clkdiv(&c, clkdiv);
56
57 // MOSI, SCK output are low, MISO is input
58 pio_sm_set_pins_with_mask(pio, sm, 0 , (1u << pin_sck) | (1u << pin_mosi));
59 pio_sm_set_pindirs_with_mask(pio, sm, (1u << pin_sck) | (1u << pin_mosi), (1u << pin_sck)
| (1u << pin_mosi) | (1u << pin_miso));
60 pio_gpio_init(pio, pin_mosi);
61 pio_gpio_init(pio, pin_miso);
62 pio_gpio_init(pio, pin_sck);
63
64 // The pin muxes can be configured to invert the output (among other things
65 // and this is a cheesy way to get CPOL=1
66 gpio_set_outover(pin_sck, cpol? GPIO_OVERRIDE_INVERT : GPIO_OVERRIDE_NORMAL);
67 // SPI is synchronous, so bypass input synchroniser to reduce input delay.
68 hw_set_bits(&pio->input_sync_bypass, 1u << pin_miso);
69
70 pio_sm_init(pio, sm, prog_offs, &c);
71 pio_sm_set_enabled(pio, sm, true);
72 }


The state machine will now immediately begin to shift out any data appearing in the TX FIFO, and push received data
into the RX FIFO.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/spi/pio_spi.c Lines 18 - 34


18 void __time_critical_func(pio_spi_write8_blocking)(const pio_spi_inst_t *spi, const uint8_t
*src, size_t len) {
19 size_t tx_remain = len, rx_remain = len;
20 // Do 8 bit accesses on FIFO, so that write data is byte-replicated. This
21 // gets us the left-justification for free (for MSB-first shift-out)
22 io_rw_8 *txfifo = (io_rw_8 *) &spi->pio->txf[spi->sm];
23 io_rw_8 *rxfifo = (io_rw_8 *) &spi->pio->rxf[spi->sm];
24 while (tx_remain || rx_remain) {
25 if (tx_remain && !pio_sm_is_tx_fifo_full(spi->pio, spi->sm)) {
26 *txfifo = *src++;
27 --tx_remain;
28 }

3.6. Examples **344**



29 if (rx_remain && !pio_sm_is_rx_fifo_empty(spi->pio, spi->sm)) {
30 (void) *rxfifo;
31 --rx_remain;
32 }
33 }
34 }


Putting this all together, this complete C program will loop back some data through a PIO SPI at 1MHz, with all four
CPOL/CPHA combinations:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/spi/spi_loopback.c


$00A01 /**
$00A02 * Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
$00A03 *
$00A04 * SPDX-License-Identifier: BSD-3-Clause
$00A05 */
$00A06
$00A07 #include <stdlib.h>
$00A08 #include <stdio.h>
$00A09
10 #include "pico/stdlib.h"
11 #include "pio_spi.h"
12
13 // This program instantiates a PIO SPI with each of the four possible
14 // CPOL/CPHA combinations, with the serial input and output pin mapped to the
15 // same GPIO. Any data written into the state machine's TX FIFO should then be
16 // serialised, deserialised, and reappear in the state machine's RX FIFO.
17
18 #define PIN_SCK 18
19 #define PIN_MOSI 16
20 #define PIN_MISO 16 // same as MOSI, so we get loopback
21
22 #define BUF_SIZE 20
23
24 void test(const pio_spi_inst_t *spi) {
25 static uint8_t txbuf[BUF_SIZE];
26 static uint8_t rxbuf[BUF_SIZE];
27 printf("TX:");
28 for (int i = 0 ; i < BUF_SIZE; ++i) {
29 txbuf[i] = rand() >> 16 ;
30 rxbuf[i] = 0 ;
31 printf(" %02x", (int) txbuf[i]);
32 }
33 printf("\n");
34
35 pio_spi_write8_read8_blocking(spi, txbuf, rxbuf, BUF_SIZE);
36
37 printf("RX:");
38 bool mismatch = false;
39 for (int i = 0 ; i < BUF_SIZE; ++i) {
40 printf(" %02x", (int) rxbuf[i]);
41 mismatch = mismatch || rxbuf[i] != txbuf[i];
42 }
43 if (mismatch)
44 printf("\nNope\n");
45 else
46 printf("\nOK\n");
47 }
48
49 int main() {
50 stdio_init_all();

3.6. Examples **345**



51
52 pio_spi_inst_t spi = {
53 .pio = pio0,
54 .sm = 0
55 };
56 float clkdiv = 31. 25 f; // 1 MHz @ 125 clk_sys
57 uint cpha0_prog_offs = pio_add_program(spi.pio, &spi_cpha0_program);
58 uint cpha1_prog_offs = pio_add_program(spi.pio, &spi_cpha1_program);
59
60 for (int cpha = 0 ; cpha <= 1 ; ++cpha) {
61 for (int cpol = 0 ; cpol <= 1 ; ++cpol) {
62 printf("CPHA = %d, CPOL = %d\n", cpha, cpol);
63 pio_spi_init(spi.pio, spi.sm,
64 cpha? cpha1_prog_offs : cpha0_prog_offs,
65 8 , // 8 bits per SPI frame
66 clkdiv,
67 cpha,
68 cpol,
69 PIN_SCK,
70 PIN_MOSI,
71 PIN_MISO
72 );
73 test(&spi);
74 sleep_ms( 10 );
75 }
76 }
77 }

**3.6.2. WS2812 LEDs**


WS2812 LEDs are driven by a proprietary pulse-width serial format, with a wide positive pulse representing a "1" bit, and
narrow positive pulse a "0". Each LED has a serial input and a serial output; LEDs are connected in a chain, with each
serial input connected to the previous LED’s serial output.


Symbol
Output

_Figure 51. WS2812line format. Wide_ 1 0 0 1 Latch

_positive pulse for 1,
narrow positive pulse
for 0, very long
negative pulse for
latch enable_


LEDs consume 24 bits of pixel data, then pass any additional input data on to their output. In this way a single serial
burst can individually program the colour of each LED in a chain. A long negative pulse latches the pixel data into the
LEDs.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/ws2812/ws2812.pio Lines 7 - 26


$00A07 .program ws2812
$00A08 .side_set 1
$00A09
10 .define public T1 2
11 .define public T2 5
12 .define public T3 3
13
14 .lang_opt python sideset_init = pico.PIO.OUT_HIGH
15 .lang_opt python out_init = pico.PIO.OUT_HIGH
16 .lang_opt python out_shiftdir = 1
17
18 .wrap_target
19 bitloop:
20 out x, 1 side 0 [T3 - 1] ; Side-set still takes place when instruction stalls
21 jmp !x do_zero side 1 [T1 - 1] ; Branch on the bit we shifted out. Positive pulse
22 do_one:

3.6. Examples **346**



23 jmp bitloop side 1 [T2 - 1] ; Continue driving high, for a long pulse
24 do_zero:
25 nop side 0 [T2 - 1] ; Or drive low, for a short pulse
26 .wrap


This program shifts bits from the OSR into X, and produces a wide or narrow pulse on side-set pin 0, based on the value
of each data bit. Autopull must be configured, with a threshold of 24. Software can then write 24-bit pixel values into the
FIFO, and these will be serialised to a chain of WS2812 LEDs. The .pio file contains a C helper function to set this up:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/ws2812/ws2812.pio Lines 31 - 47


31 static inline void ws2812_program_init(PIO pio, uint sm, uint offset, uint pin, float freq,
bool rgbw) {
32
33 pio_gpio_init(pio, pin);
34 pio_sm_set_consecutive_pindirs(pio, sm, pin, 1 , true);
35
36 pio_sm_config c = ws2812_program_get_default_config(offset);
37 sm_config_set_sideset_pins(&c, pin);
38 sm_config_set_out_shift(&c, false, true, rgbw? 32 : 24 );
39 sm_config_set_fifo_join(&c, PIO_FIFO_JOIN_TX);
40
41 int cycles_per_bit = ws2812_T1 + ws2812_T2 + ws2812_T3;
42 float div = clock_get_hz(clk_sys) / (freq * cycles_per_bit);
43 sm_config_set_clkdiv(&c, div);
44
45 pio_sm_init(pio, sm, offset, &c);
46 pio_sm_set_enabled(pio, sm, true);
47 }


Because the shift is MSB-first, and our pixels aren’t a power of two size (so we can’t rely on the narrow write replication
behaviour on RP2040 to fan out the bits for us), we need to preshift the values written to the TX FIFO.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/ws2812/ws2812.c Lines 25 - 27


25 static inline void put_pixel(uint32_t pixel_grb) {
26 pio_sm_put_blocking(pio0, 0 , pixel_grb << 8u);
27 }


To DMA the pixels, we could instead set the autopull threshold to 8 bits, set the DMA transfer size to 8 bits, and write a
byte at a time into the FIFO. Each pixel would be 3 one-byte transfers. Because of how the bus fabric and DMA on
RP2040 work, each byte the DMA transfers will appear replicated four times when written to a 32-bit IO register, so
effectively your data is at both ends of the shift register, and you can shift in either direction without worry.


More detail?


The WS2812 example is the subject of a tutorial in the Raspberry Pi Pico C/C++ SDK document, in the
PIO chapter. The tutorial dissects the ws2812 program line by line, traces through how the program
executes, and shows wave diagrams of the GPIO output at every point in the program.

**3.6.3. UART TX**

3.6. Examples **347**



Bit Clock
TX
State


0 1 2 3 4 5 6 7
Idle Start Data (LSB first) Stop

_Figure 52. UART serial
format. The line is
high when idle. The
transmitter pulls the
line down for one bit
period to signify the
start of a serial frame
(the "start bit"), and a
small, fixed number of
data bits follows. The
line returns to the idle
state for at least one
bit period (the "stop
bit") before the next
serial frame can
begin._


This program implements the transmit component of a universal asynchronous receive/transmit (UART) serial
peripheral. Perhaps it would be more correct to refer to this as a UAT.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/uart_tx/uart_tx.pio Lines 7 - 17


$00A07 .program uart_tx
$00A08 .side_set 1 opt
$00A09
10 ; An 8n1 UART transmit program.
11 ; OUT pin 0 and side-set pin 0 are both mapped to UART TX pin.
12
13 pull side 1 [7] ; Assert stop bit, or stall with line in idle state
14 set x, 7 side 0 [7] ; Preload bit counter, assert start bit for 8 clocks
15 bitloop: ; This loop will run 8 times (8n1 UART)
16 out pins, 1 ; Shift 1 bit from OSR to the first OUT pin
17 jmp x-- bitloop [6] ; Each loop iteration is 8 cycles.


As written, it will:

- Stall with the pin driven high until data appears (noting that side-set takes effect even when the state machine is
    stalled)
- Assert a start bit, for 8 SM execution cycles
- Shift out 8 data bits, each lasting for 8 cycles
- Return to the idle line state for at least 8 cycles before asserting the next start bit
If the state machine’s clock divider is configured to run at 8 times the desired baud rate, this program will transmit well-
formed UART serial frames, whenever data is pushed to the TX FIFO either by software or the system DMA. To extend
the program to cover different frame sizes (different numbers of data bits), the set x, 7 could be replaced with mov x, y,
so that the y scratch register becomes a per-SM configuration register for UART frame size.
The .pio file in the SDK also contains this function, for configuring the pins and the state machine, once the program
has been loaded into the PIO instruction memory:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/uart_tx/uart_tx.pio Lines 23 - 50


23 static inline void uart_tx_program_init(PIO pio, uint sm, uint offset, uint pin_tx, uint
baud) {
24 // Tell PIO to initially drive output-high on the selected pin, then map PIO
25 // onto that pin with the IO muxes.
26 pio_sm_set_pins_with_mask(pio, sm, 1u << pin_tx, 1u << pin_tx);
27 pio_sm_set_pindirs_with_mask(pio, sm, 1u << pin_tx, 1u << pin_tx);
28 pio_gpio_init(pio, pin_tx);
29
30 pio_sm_config c = uart_tx_program_get_default_config(offset);
31
32 // OUT shifts to right, no autopull
33 sm_config_set_out_shift(&c, true, false, 32 );
34
35 // We are mapping both OUT and side-set to the same pin, because sometimes
36 // we need to assert user data onto the pin (with OUT) and sometimes
37 // assert constant values (start/stop bit)
38 sm_config_set_out_pins(&c, pin_tx, 1 );
39 sm_config_set_sideset_pins(&c, pin_tx);
40
41 // We only need TX, so get an 8-deep FIFO!

3.6. Examples **348**



42 sm_config_set_fifo_join(&c, PIO_FIFO_JOIN_TX);
43
44 // SM transmits 1 bit per 8 execution cycles.
45 float div = (float)clock_get_hz(clk_sys) / ( 8 * baud);
46 sm_config_set_clkdiv(&c, div);
47
48 pio_sm_init(pio, sm, offset, &c);
49 pio_sm_set_enabled(pio, sm, true);
50 }


The state machine is configured to shift right in out instructions, because UARTs typically send data LSB-first. Once
configured, the state machine will print any characters pushed to the TX FIFO.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/uart_tx/uart_tx.pio Lines 52 - 54


52 static inline void uart_tx_program_putc(PIO pio, uint sm, char c) {
53 pio_sm_put_blocking(pio, sm, (uint32_t)c);
54 }


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/uart_tx/uart_tx.pio Lines 56 - 59


56 static inline void uart_tx_program_puts(PIO pio, uint sm, const char *s) {
57 while (*s)
58 uart_tx_program_putc(pio, sm, *s++);
59 }


The example program in the SDK will configure one PIO state machine as a UART TX peripheral, and use it to print a
message on GPIO 0 at 115200 baud once per second.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/uart_tx/uart_tx.c


$00A01 /**
$00A02 * Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
$00A03 *
$00A04 * SPDX-License-Identifier: BSD-3-Clause
$00A05 */
$00A06
$00A07 #include "pico/stdlib.h"
$00A08 #include "hardware/pio.h"
$00A09 #include "uart_tx.pio.h"
10
11 int main() {
12 // We're going to use PIO to print "Hello, world!" on the same GPIO which we
13 // normally attach UART0 to.
14 const uint PIN_TX = 0 ;
15 // This is the same as the default UART baud rate on Pico
16 const uint SERIAL_BAUD = 115200 ;
17
18 PIO pio = pio0;
19 uint sm = 0 ;
20 uint offset = pio_add_program(pio, &uart_tx_program);
21 uart_tx_program_init(pio, sm, offset, PIN_TX, SERIAL_BAUD);
22
23 while (true) {
24 uart_tx_program_puts(pio, sm, "Hello, world! (from PIO!)\n");
25 sleep_ms( 1000 );
26 }

3.6. Examples **349**



27 }


With the two PIO instances on RP2040, this could be extended to 8 additional UART TX interfaces, on 8 different pins,
with 8 different baud rates.

**3.6.4. UART RX**


Recalling Figure 52 showing the format of an 8n1 UART:


Bit Clock
TX
State


0 1 2 3 4 5 6 7
Idle Start Data (LSB first) Stop


We can recover the data by waiting for the start bit, sampling 8 times with the correct timing, and pushing the result to
the RX FIFO. Below is possibly the shortest program which can do this:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/uart_rx/uart_rx.pio Lines 7 - 18


$00A07 .program uart_rx_mini
$00A08
$00A09 ; Minimum viable 8n1 UART receiver. Wait for the start bit, then sample 8 bits
10 ; with the correct timing.
11 ; IN pin 0 is mapped to the GPIO used as UART RX.
12 ; Autopush must be enabled, with a threshold of 8.
13
14 wait 0 pin 0 ; Wait for start bit
15 set x, 7 [10] ; Preload bit counter, delay until eye of first data bit
16 bitloop: ; Loop 8 times
17 in pins, 1 ; Sample data
18 jmp x-- bitloop [6] ; Each iteration is 8 cycles


This works, but it has some annoying characteristics, like repeatedly outputting NUL characters if the line is stuck low.
Ideally, we would want to drop data that is not correctly framed by a start and stop bit (and set some sticky flag to
indicate this has happened), and pause receiving when the line is stuck low for long periods. We can add these to our
program, at the cost of a few more instructions.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/uart_rx/uart_rx.pio Lines 43 - 62


43 .program uart_rx
44
45 ; Slightly more fleshed-out 8n1 UART receiver which handles framing errors and
46 ; break conditions more gracefully.
47 ; IN pin 0 and JMP pin are both mapped to the GPIO used as UART RX.
48
49 start:
50 wait 0 pin 0 ; Stall until start bit is asserted
51 set x, 7 [10] ; Preload bit counter, then delay until halfway through
52 bitloop: ; the first data bit (12 cycles incl wait, set).
53 in pins, 1 ; Shift data bit into ISR
54 jmp x-- bitloop [6] ; Loop 8 times, each loop iteration is 8 cycles
55 jmp pin good_stop ; Check stop bit (should be high)
56
57 irq 4 rel ; Either a framing error or a break. Set a sticky flag,
58 wait 1 pin 0 ; and wait for line to return to idle state.
59 jmp start ; Don't push data if we didn't see good framing.
60
61 good_stop: ; No delay before returning to start; a little slack is

3.6. Examples **350**



62 push ; important in case the TX clock is slightly too fast.


The second example does not use autopush (Section 3.5.4), preferring instead to use an explicit push instruction, so that
it can condition the push on whether a correct stop bit is seen. The .pio file includes a helper function which configures
the state machine and connects it to a GPIO with the pullup enabled:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/uart_rx/uart_rx.pio Lines 66 - 84


66 static inline void uart_rx_program_init(PIO pio, uint sm, uint offset, uint pin, uint baud) {
67 pio_sm_set_consecutive_pindirs(pio, sm, pin, 1 , false);
68 pio_gpio_init(pio, pin);
69 gpio_pull_up(pin);
70
71 pio_sm_config c = uart_rx_program_get_default_config(offset);
72 sm_config_set_in_pins(&c, pin); // for WAIT, IN
73 sm_config_set_jmp_pin(&c, pin); // for JMP
74 // Shift to right, autopush disabled
75 sm_config_set_in_shift(&c, true, false, 32 );
76 // Deeper FIFO as we're not doing any TX
77 sm_config_set_fifo_join(&c, PIO_FIFO_JOIN_RX);
78 // SM transmits 1 bit per 8 execution cycles.
79 float div = (float)clock_get_hz(clk_sys) / ( 8 * baud);
80 sm_config_set_clkdiv(&c, div);
81
82 pio_sm_init(pio, sm, offset, &c);
83 pio_sm_set_enabled(pio, sm, true);
84 }


To correctly receive data which is sent LSB-first, the ISR is configured to shift to the right. After shifting in 8 bits, this
unfortunately leaves our 8 data bits in bits 31:24 of the ISR, with 24 zeroes in the LSBs. One option here is an in null, 24
instruction to shuffle the ISR contents down to 7:0. Another is to read from the FIFO at an offset of 3 bytes, with an 8-bit
read, so that the processor’s bus hardware (or the DMA’s) picks out the relevant byte for free:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/uart_rx/uart_rx.pio Lines 86 - 92


86 static inline char uart_rx_program_getc(PIO pio, uint sm) {
87 // 8-bit read from the uppermost byte of the FIFO, as data is left-justified
88 io_rw_8 *rxfifo_shift = (io_rw_8*)&pio->rxf[sm] + 3 ;
89 while (pio_sm_is_rx_fifo_empty(pio, sm))
90 tight_loop_contents();
91 return (char)*rxfifo_shift;
92 }


An example program shows how this UART RX program can be used to receive characters sent by one of the hardware
UARTs on RP2040. A wire must be connected from GPIO4 to GPIO3 for this program to function. To make the wrangling
of 3 different serial ports a little easier, this program uses core 1 to print out a string on the test UART (UART 1), and the
code running on core 0 will pull out characters from the PIO state machine, and pass them along to the UART used for
the debug console (UART 0). Another approach here would be interrupt-based IO, using PIO’s FIFO IRQs. If the
SM0_RXNEMPTY bit is set in the IRQ0_INTE register, then PIO will raise its first interrupt request line whenever there is a
character in state machine 0’s RX FIFO.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/uart_rx/uart_rx.c


$00A01 /**
$00A02 * Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
$00A03 *
$00A04 * SPDX-License-Identifier: BSD-3-Clause

3.6. Examples **351**



$00A05 */
$00A06
$00A07 #include <stdio.h>
$00A08
$00A09 #include "pico/stdlib.h"
10 #include "pico/multicore.h"
11 #include "hardware/pio.h"
12 #include "hardware/uart.h"
13 #include "uart_rx.pio.h"
14
15 // This program
16 // - Uses UART1 (the spare UART, by default) to transmit some text
17 // - Uses a PIO state machine to receive that text
18 // - Prints out the received text to the default console (UART0)
19 // This might require some reconfiguration on boards where UART1 is the
20 // default UART.
21
22 #define SERIAL_BAUD PICO_DEFAULT_UART_BAUD_RATE
23 #define HARD_UART_INST uart1
24
25 // You'll need a wire from GPIO4 -> GPIO3
26 #define HARD_UART_TX_PIN 4
27 #define PIO_RX_PIN 3
28
29 // Ask core 1 to print a string, to make things easier on core 0
30 void core1_main() {
31 const char *s = (const char *) multicore_fifo_pop_blocking();
32 uart_puts(HARD_UART_INST, s);
33 }
34
35 int main() {
36 // Console output (also a UART, yes it's confusing)
37 setup_default_uart();
38 printf("Starting PIO UART RX example\n");
39
40 // Set up the hard UART we're going to use to print characters
41 uart_init(HARD_UART_INST, SERIAL_BAUD);
42 gpio_set_function(HARD_UART_TX_PIN, GPIO_FUNC_UART);
43
44 // Set up the state machine we're going to use to receive them.
45 PIO pio = pio0;
46 uint sm = 0 ;
47 uint offset = pio_add_program(pio, &uart_rx_program);
48 uart_rx_program_init(pio, sm, offset, PIO_RX_PIN, SERIAL_BAUD);
49
50 // Tell core 1 to print some text to uart1 as fast as it can
51 multicore_launch_core1(core1_main);
52 const char *text = "Hello, world from PIO! (Plus 2 UARTs and 2 cores, for complex
reasons)\n";
53 multicore_fifo_push_blocking((uint32_t) text);
54
55 // Echo characters received from PIO to the console
56 while (true) {
57 char c = uart_rx_program_getc(pio, sm);
58 putchar(c);
59 }
60 }

3.6. Examples **352**


**3.6.5. Manchester Serial TX and RX**

_Figure 53. Manchester
serial line code. Each
data bit is represented
by either a high pulse
followed by a low
pulse (representing a
'0' bit) or a low pulse
followed by a high
pulse (a '1' bit)._


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/manchester_encoding/manchester_encoding.pio Lines 7 - 29


$00A07 .program manchester_tx
$00A08 .side_set 1 opt
$00A09
10 ; Transmit one bit every 12 cycles. a '0' is encoded as a high-low sequence
11 ; (each part lasting half a bit period, or 6 cycles) and a '1' is encoded as a
12 ; low-high sequence.
13 ;
14 ; Side-set bit 0 must be mapped to the GPIO used for TX.
15 ; Autopull must be enabled -- this program does not care about the threshold.
16 ; The program starts at the public label 'start'.
17
18 .wrap_target
19 do_1:
20 nop side 0 [5] ; Low for 6 cycles (5 delay, +1 for nop)
21 jmp get_bit side 1 [3] ; High for 4 cycles. 'get_bit' takes another 2 cycles
22 do_0:
23 nop side 1 [5] ; Output high for 6 cycles
24 nop side 0 [3] ; Output low for 4 cycles
25 public start:
26 get_bit:
27 out x, 1 ; Always shift out one bit from OSR to X, so we can
28 jmp !x do_0 ; branch on it. Autopull refills the OSR when empty.
29 .wrap


Starting from the label called start, this program shifts one data bit at a time into the X register, so that it can branch on
the value. Depending on the outcome, it uses side-set to drive either a 1-0 or 0-1 sequence onto the chosen GPIO. This
program uses autopull (Section 3.5.4.2) to automatically replenish the OSR from the TX FIFO once a certain amount of
data has been shifted out, without interrupting program control flow or timing. This feature is enabled by a helper
function in the .pio file which configures and starts the state machine:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/manchester_encoding/manchester_encoding.pio Lines 32 - 45


32 static inline void manchester_tx_program_init(PIO pio, uint sm, uint offset, uint pin, float
div) {
33 pio_sm_set_pins_with_mask(pio, sm, 0 , 1u << pin);
34 pio_sm_set_consecutive_pindirs(pio, sm, pin, 1 , true);
35 pio_gpio_init(pio, pin);
36
37 pio_sm_config c = manchester_tx_program_get_default_config(offset);
38 sm_config_set_sideset_pins(&c, pin);
39 sm_config_set_out_shift(&c, true, true, 32 );
40 sm_config_set_fifo_join(&c, PIO_FIFO_JOIN_TX);
41 sm_config_set_clkdiv(&c, div);
42 pio_sm_init(pio, sm, offset + manchester_tx_offset_start, &c);
43
44 pio_sm_set_enabled(pio, sm, true);
45 }


Another state machine can be programmed to recover the original data from the transmitted signal:

3.6. Examples **353**



Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/manchester_encoding/manchester_encoding.pio Lines 48 - 70


48 .program manchester_rx
49
50 ; Assumes line is idle low, first bit is 0
51 ; One bit is 12 cycles
52 ; a '0' is encoded as 10
53 ; a '1' is encoded as 01
54 ;
55 ; Both the IN base and the JMP pin mapping must be pointed at the GPIO used for RX.
56 ; Autopush must be enabled.
57 ; Before enabling the SM, it should be placed in a 'wait 1, pin` state, so that
58 ; it will not start sampling until the initial line idle state ends.
59
60 start_of_0: ; We are 0.25 bits into a 0 - signal is high
61 wait 0 pin 0 ; Wait for the 1->0 transition - at this point we are 0.5 into the bit
62 in y, 1 [8] ; Emit a 0, sleep 3/4 of a bit
63 jmp pin start_of_0 ; If signal is 1 again, it's another 0 bit, otherwise it's a 1
64
65 .wrap_target
66 start_of_1: ; We are 0.25 bits into a 1 - signal is 1
67 wait 1 pin 0 ; Wait for the 0->1 transition - at this point we are 0.5 into the bit
68 in x, 1 [8] ; Emit a 1, sleep 3/4 of a bit
69 jmp pin start_of_0 ; If signal is 0 again, it's another 1 bit otherwise it's a 0
70 .wrap


The main complication here is staying aligned to the input transitions, as the transmitter’s and receiver’s clocks may
drift relative to one another. In Manchester code there is always a transition in the centre of the symbol, and based on
the initial line state (high or low) we know the direction of this transition, so we can use a wait instruction to
resynchronise to the line transitions on every data bit.
This program expects the X and Y registers to be initialised with the values 1 and 0 respectively, so that a constant 1 or
0 can be provided to the in instruction. The code that configures the state machine initialises these registers by
executing some set instructions before setting the program running.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/manchester_encoding/manchester_encoding.pio Lines 73 - 93


73 static inline void manchester_rx_program_init(PIO pio, uint sm, uint offset, uint pin, float
div) {
74 pio_sm_set_consecutive_pindirs(pio, sm, pin, 1 , false);
75 pio_gpio_init(pio, pin);
76
77 pio_sm_config c = manchester_rx_program_get_default_config(offset);
78 sm_config_set_in_pins(&c, pin); // for WAIT
79 sm_config_set_jmp_pin(&c, pin); // for JMP
80 sm_config_set_in_shift(&c, true, true, 32 );
81 sm_config_set_fifo_join(&c, PIO_FIFO_JOIN_RX);
82 sm_config_set_clkdiv(&c, div);
83 pio_sm_init(pio, sm, offset, &c);
84
85 // X and Y are set to 0 and 1, to conveniently emit these to ISR/FIFO.
86 pio_sm_exec(pio, sm, pio_encode_set(pio_x, 1 ));
87 pio_sm_exec(pio, sm, pio_encode_set(pio_y, 0 ));
88 // Assume line is idle low, and first transmitted bit is 0. Put SM in a
89 // wait state before enabling. RX will begin once the first 0 symbol is
90 // detected.
91 pio_sm_exec(pio, sm, pio_encode_wait_pin( 1 , 0 ) | pio_encode_delay( 2 ));
92 pio_sm_set_enabled(pio, sm, true);
93 }

3.6. Examples **354**



The example C program in the SDK will transmit Manchester serial data from GPIO2 to GPIO3 at approximately 10Mbps
(assuming a system clock of 125MHz).


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/manchester_encoding/manchester_encoding.c Lines 20 - 43


20 int main() {
21 stdio_init_all();
22
23 PIO pio = pio0;
24 uint sm_tx = 0 ;
25 uint sm_rx = 1 ;
26
27 uint offset_tx = pio_add_program(pio, &manchester_tx_program);
28 uint offset_rx = pio_add_program(pio, &manchester_rx_program);
29 printf("Transmit program loaded at %d\n", offset_tx);
30 printf("Receive program loaded at %d\n", offset_rx);
31
32 manchester_tx_program_init(pio, sm_tx, offset_tx, pin_tx, 1 .f);
33 manchester_rx_program_init(pio, sm_rx, offset_rx, pin_rx, 1 .f);
34
35 pio_sm_set_enabled(pio, sm_tx, false);
36 pio_sm_put_blocking(pio, sm_tx, 0 );
37 pio_sm_put_blocking(pio, sm_tx, 0x0ff0a55a);
38 pio_sm_put_blocking(pio, sm_tx, 0x12345678);
39 pio_sm_set_enabled(pio, sm_tx, true);
40
41 for (int i = 0 ; i < 3 ; ++i)
42 printf("%08x\n", pio_sm_get_blocking(pio, sm_rx));
43 }

**3.6.6. Differential Manchester (BMC) TX and RX**

_Figure 54. Differential
Manchester serial line
code, also known as
biphase mark code
(BMC). The line
transitions at the start
of every bit period.
The presence of a
transition in the centre
of the bit period
signifies a_ 1 _data bit,
and the absence, a_ 0
_bit. These encoding
rules are the same
whether the line has
an initial high or low
state._


The transmit program is similar to the Manchester example: it repeatedly shifts a bit from the OSR into X (relying on
autopull to refill the OSR in the background), branches, and drives a GPIO up and down based on the value of this bit.
The added complication is that the pattern we drive onto the pin depends not just on the value of the data bit, as with
vanilla Manchester encoding, but also on the state the line was left in at the end of the last bit period. This is illustrated
in Figure 54, where the pattern is inverted if the line is initially high. To cope with this, there are two copies of the test-
and-drive code, one for each initial line state, and these are linked together in the correct order by a sequence of jumps.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/differential_manchester/differential_manchester.pio Lines 7 - 34


$00A07 .program differential_manchester_tx
$00A08 .side_set 1 opt
$00A09
10 ; Transmit one bit every 16 cycles. In each bit period:
11 ; - A '0' is encoded as a transition at the start of the bit period
12 ; - A '1' is encoded as a transition at the start *and* in the middle
13 ;
14 ; Side-set bit 0 must be mapped to the data output pin.
15 ; Autopull must be enabled.
16
17 public start:
18 initial_high:
19 out x, 1 ; Start of bit period: always assert transition
20 jmp !x high_0 side 1 [6] ; Test the data bit we just shifted out of OSR

3.6. Examples **355**



21 high_1:
22 nop
23 jmp initial_high side 0 [6] ; For `1` bits, also transition in the middle
24 high_0:
25 jmp initial_low [7] ; Otherwise, the line is stable in the middle
26
27 initial_low:
28 out x, 1 ; Always shift 1 bit from OSR to X so we can
29 jmp !x low_0 side 0 [6] ; branch on it. Autopull refills OSR for us.
30 low_1:
31 nop
32 jmp initial_low side 1 [6] ; If there are two transitions, return to
33 low_0:
34 jmp initial_high [7] ; the initial line state is flipped!


The .pio file also includes a helper function to initialise a state machine for differential Manchester TX, and connect it to
a chosen GPIO. We arbitrarily choose a 32-bit frame size and LSB-first serialisation (shift_to_right is true in
sm_config_set_out_shift), but as the program operates on one bit at a time, we could change this by reconfiguring the
state machine.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/differential_manchester/differential_manchester.pio Lines 37 - 52


37 static inline void differential_manchester_tx_program_init(PIO pio, uint sm, uint offset,
uint pin, float div) {
38 pio_sm_set_pins_with_mask(pio, sm, 0 , 1u << pin);
39 pio_sm_set_consecutive_pindirs(pio, sm, pin, 1 , true);
40 pio_gpio_init(pio, pin);
41
42 pio_sm_config c = differential_manchester_tx_program_get_default_config(offset);
43 sm_config_set_sideset_pins(&c, pin);
44 sm_config_set_out_shift(&c, true, true, 32 );
45 sm_config_set_fifo_join(&c, PIO_FIFO_JOIN_TX);
46 sm_config_set_clkdiv(&c, div);
47 pio_sm_init(pio, sm, offset + differential_manchester_tx_offset_start, &c);
48
49 // Execute a blocking pull so that we maintain the initial line state until data is
available
50 pio_sm_exec(pio, sm, pio_encode_pull(false, true));
51 pio_sm_set_enabled(pio, sm, true);
52 }


The RX program uses the following strategy:

- Wait until the initial transition at the start of the bit period, so we stay aligned to the transmit clock
- Then wait 3/4 of the configured bit period, so that we are centred on the second half-bit-period (see Figure 54)
- Sample the line at this point to determine whether there are one or two transitions in this bit period
- Repeat


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/differential_manchester/differential_manchester.pio Lines 54 - 84


54 .program differential_manchester_rx
55
56 ; Assumes line is idle low
57 ; One bit is 16 cycles. In each bit period:
58 ; - A '0' is encoded as a transition at time 0
59 ; - A '1' is encoded as a transition at time 0 and a transition at time T/2
60 ;
61 ; The IN mapping and the JMP pin select must both be mapped to the GPIO used for

3.6. Examples **356**



62 ; RX data. Autopush must be enabled.
63
64 public start:
65 initial_high: ; Find rising edge at start of bit period
66 wait 1 pin, 0 [11] ; Delay to eye of second half-period (i.e 3/4 of way
67 jmp pin high_0 ; through bit) and branch on RX pin high/low.
68 high_1:
69 in x, 1 ; Second transition detected (a `1` data symbol)
70 jmp initial_high
71 high_0:
72 in y, 1 [1] ; Line still high, no centre transition (data is `0`)
73 ; Fall-through
74
75 .wrap_target
76 initial_low: ; Find falling edge at start of bit period
77 wait 0 pin, 0 [11] ; Delay to eye of second half-period
78 jmp pin low_1
79 low_0:
80 in y, 1 ; Line still low, no centre transition (data is `0`)
81 jmp initial_high
82 low_1: ; Second transition detected (data is `1`)
83 in x, 1 [1]
84 .wrap


This code assumes that X and Y have the values 1 and 0, respectively. This is arranged for by the included C helper
function:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/differential_manchester/differential_manchester.pio Lines 87 - 103


$00A087 static inline void differential_manchester_rx_program_init(PIO pio, uint sm, uint offset,
uint pin, float div) {
$00A088 pio_sm_set_consecutive_pindirs(pio, sm, pin, 1 , false);
$00A089 pio_gpio_init(pio, pin);
$00A090
$00A091 pio_sm_config c = differential_manchester_rx_program_get_default_config(offset);
$00A092 sm_config_set_in_pins(&c, pin); // for WAIT
$00A093 sm_config_set_jmp_pin(&c, pin); // for JMP
$00A094 sm_config_set_in_shift(&c, true, true, 32 );
$00A095 sm_config_set_fifo_join(&c, PIO_FIFO_JOIN_RX);
$00A096 sm_config_set_clkdiv(&c, div);
$00A097 pio_sm_init(pio, sm, offset, &c);
$00A098
$00A099 // X and Y are set to 0 and 1, to conveniently emit these to ISR/FIFO.
100 pio_sm_exec(pio, sm, pio_encode_set(pio_x, 1 ));
101 pio_sm_exec(pio, sm, pio_encode_set(pio_y, 0 ));
102 pio_sm_set_enabled(pio, sm, true);
103 }


All the pieces now exist to loopback some serial data over a wire between two GPIOs.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/differential_manchester/differential_manchester.c


$00A01 /**
$00A02 * Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
$00A03 *
$00A04 * SPDX-License-Identifier: BSD-3-Clause
$00A05 */
$00A06
$00A07 #include <stdio.h>
$00A08

3.6. Examples **357**



$00A09 #include "pico/stdlib.h"
10 #include "hardware/pio.h"
11 #include "differential_manchester.pio.h"
12
13 // Differential serial transmit/receive example
14 // Need to connect a wire from GPIO2 -> GPIO3
15
16 const uint pin_tx = 2 ;
17 const uint pin_rx = 3 ;
18
19 int main() {
20 stdio_init_all();
21
22 PIO pio = pio0;
23 uint sm_tx = 0 ;
24 uint sm_rx = 1 ;
25
26 uint offset_tx = pio_add_program(pio, &differential_manchester_tx_program);
27 uint offset_rx = pio_add_program(pio, &differential_manchester_rx_program);
28 printf("Transmit program loaded at %d\n", offset_tx);
29 printf("Receive program loaded at %d\n", offset_rx);
30
31 // Configure state machines, set bit rate at 5 Mbps
32 differential_manchester_tx_program_init(pio, sm_tx, offset_tx, pin_tx, 125 .f / ( 16 * 5 ));
33 differential_manchester_rx_program_init(pio, sm_rx, offset_rx, pin_rx, 125 .f / ( 16 * 5 ));
34
35 pio_sm_set_enabled(pio, sm_tx, false);
36 pio_sm_put_blocking(pio, sm_tx, 0 );
37 pio_sm_put_blocking(pio, sm_tx, 0x0ff0a55a);
38 pio_sm_put_blocking(pio, sm_tx, 0x12345678);
39 pio_sm_set_enabled(pio, sm_tx, true);
40
41 for (int i = 0 ; i < 3 ; ++i)
42 printf("%08x\n", pio_sm_get_blocking(pio, sm_rx));
43 }

**3.6.7. I2C**

3.6. Examples **358**


_Figure 55. A 1-byte I2C
read transfer. In the
idle state, both lines
float high. The initiator
drives SDA low (a
Start condition),
followed by 7 address
bits A6-A0, and a
direction bit
(Read/nWrite). The
target drives SDA low
to acknowledge the
address (ACK). Data
bytes follow. The
target serialises data
on SDA, clocked out
by SCL. Every 9th
clock, the_ **initiator**
_pulls SDA low to
acknowledge the data,
except on the last
byte, where it leaves
the line high (NAK).
Releasing SDA whilst
SCL is high is a Stop
condition, returning
the bus to idle._


I2C is an ubiquitous serial bus first described in the Dead Sea Scrolls, and later used by Philips Semiconductor. Two
wires with pullup resistors form an open-drain bus, and multiple agents address and signal one another over this bus by
driving the bus lines low, or releasing them to be pulled high. It has a number of unusual attributes:

- SCL can be held low at any time, for any duration, by any member of the bus (not necessarily the target or initiator
    of the transfer). This is known as clock stretching. The bus does not advance until all drivers release the clock.
- Members of the bus can be a target of one transfer and initiate other transfers (the master/slave roles are not
    fixed). However this is poorly supported by most I2C hardware.
- SCL is not an edge-sensitive clock, rather SDA must be valid the entire time SCL is high
- In spite of the transparency of SDA against SCL, transitions of SDA whilst SCL is high are used to mark beginning
    and end of transfers (Start/Stop), or a new address phase within one (Restart)
The PIO program listed below handles serialisation, clock stretching, and checking of ACKs in the initiator role. It
provides a mechanism for escaping PIO instructions in the FIFO datastream, to issue Start/Stop/Restart sequences at
appropriate times. Provided no unexpected NAKs are received, this can perform long sequences of I2C transfers from a
DMA buffer, without processor intervention.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/i2c/i2c.pio Lines 7 - 72


$00A07 .program i2c
$00A08 .side_set 1 opt pindirs
$00A09
10 ; TX Encoding:
11 ; | 15:10 | 9 | 8:1 | 0 |
12 ; | Instr | Final | Data | NAK |
13 ;
14 ; If Instr has a value n > 0, then this FIFO word has no
15 ; data payload, and the next n + 1 words will be executed as instructions.
16 ; Otherwise, shift out the 8 data bits, followed by the ACK bit.
17 ;
18 ; The Instr mechanism allows stop/start/repstart sequences to be programmed
19 ; by the processor, and then carried out by the state machine at defined points
20 ; in the datastream.
21 ;
22 ; The "Final" field should be set for the final byte in a transfer.
23 ; This tells the state machine to ignore a NAK: if this field is not
24 ; set, then any NAK will cause the state machine to halt and interrupt.
25 ;
26 ; Autopull should be enabled, with a threshold of 16.
27 ; Autopush should be enabled, with a threshold of 8.
28 ; The TX FIFO should be accessed with halfword writes, to ensure
29 ; the data is immediately available in the OSR.
30 ;
31 ; Pin mapping:
32 ; - Input pin 0 is SDA, 1 is SCL (if clock stretching used)
33 ; - Jump pin is SDA
34 ; - Side-set pin 0 is SCL
35 ; - Set pin 0 is SDA
36 ; - OUT pin 0 is SDA
37 ; - SCL must be SDA + 1 (for wait mapping)
38 ;
39 ; The OE outputs should be inverted in the system IO controls!
40 ; (It's possible for the inversion to be done in this program,
41 ; but costs 2 instructions: 1 for inversion, and one to cope
42 ; with the side effect of the MOV on TX shift counter.)
43

3.6. Examples **359**



44 do_nack:
45 jmp y-- entry_point ; Continue if NAK was expected
46 irq wait 0 rel ; Otherwise stop, ask for help
47
48 do_byte:
49 set x, 7 ; Loop 8 times
50 bitloop:
51 out pindirs, 1 [7] ; Serialise write data (all-ones if reading)
52 nop side 1 [2] ; SCL rising edge
53 wait 1 pin, 1 [4] ; Allow clock to be stretched
54 in pins, 1 [7] ; Sample read data in middle of SCL pulse
55 jmp x-- bitloop side 0 [7] ; SCL falling edge
56
57 ; Handle ACK pulse
58 out pindirs, 1 [7] ; On reads, we provide the ACK.
59 nop side 1 [7] ; SCL rising edge
60 wait 1 pin, 1 [7] ; Allow clock to be stretched
61 jmp pin do_nack side 0 [2] ; Test SDA for ACK/NAK, fall through if ACK
62
63 public entry_point:
64 .wrap_target
65 out x, 6 ; Unpack Instr count
66 out y, 1 ; Unpack the NAK ignore bit
67 jmp !x do_byte ; Instr == 0, this is a data record.
68 out null, 32 ; Instr > 0, remainder of this OSR is invalid
69 do_exec:
70 out exec, 16 ; Execute one instruction per FIFO word
71 jmp x-- do_exec ; Repeat n + 1 times
72 .wrap


The IO mapping required by the I2C program is quite complex, due to the different ways that the two serial lines must be
driven and sampled. One interesting feature is that state machine must drive the output enable high when the output is
low, since the bus is open-drain, so the sense of the data is inverted. This could be handled in the PIO program (e.g. mov
osr, ~osr), but instead we can use the IO controls on RP2040 to perform this inversion in the GPIO muxes, saving an
instruction.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/i2c/i2c.pio Lines 80 - 120


$00A080 static inline void i2c_program_init(PIO pio, uint sm, uint offset, uint pin_sda, uint
pin_scl) {
$00A081 assert(pin_scl == pin_sda + 1 );
$00A082 pio_sm_config c = i2c_program_get_default_config(offset);
$00A083
$00A084 // IO mapping
$00A085 sm_config_set_out_pins(&c, pin_sda, 1 );
$00A086 sm_config_set_set_pins(&c, pin_sda, 1 );
$00A087 sm_config_set_in_pins(&c, pin_sda);
$00A088 sm_config_set_sideset_pins(&c, pin_scl);
$00A089 sm_config_set_jmp_pin(&c, pin_sda);
$00A090
$00A091 sm_config_set_out_shift(&c, false, true, 16 );
$00A092 sm_config_set_in_shift(&c, false, true, 8 );
$00A093
$00A094 float div = (float)clock_get_hz(clk_sys) / ( 32 * 100000 );
$00A095 sm_config_set_clkdiv(&c, div);
$00A096
$00A097 // Try to avoid glitching the bus while connecting the IOs. Get things set
$00A098 // up so that pin is driven down when PIO asserts OE low, and pulled up
$00A099 // otherwise.
100 gpio_pull_up(pin_scl);
101 gpio_pull_up(pin_sda);

3.6. Examples **360**



102 uint32_t both_pins = (1u << pin_sda) | (1u << pin_scl);
103 pio_sm_set_pins_with_mask(pio, sm, both_pins, both_pins);
104 pio_sm_set_pindirs_with_mask(pio, sm, both_pins, both_pins);
105 pio_gpio_init(pio, pin_sda);
106 gpio_set_oeover(pin_sda, GPIO_OVERRIDE_INVERT);
107 pio_gpio_init(pio, pin_scl);
108 gpio_set_oeover(pin_scl, GPIO_OVERRIDE_INVERT);
109 pio_sm_set_pins_with_mask(pio, sm, 0 , both_pins);
110
111 // Clear IRQ flag before starting, and make sure flag doesn't actually
112 // assert a system-level interrupt (we're using it as a status flag)
113 pio_set_irq0_source_enabled(pio, (enum pio_interrupt_source) ((uint) pis_interrupt0 +
sm), false);
114 pio_set_irq1_source_enabled(pio, (enum pio_interrupt_source) ((uint) pis_interrupt0 +
sm), false);
115 pio_interrupt_clear(pio, sm);
116
117 // Configure and start SM
118 pio_sm_init(pio, sm, offset + i2c_offset_entry_point, &c);
119 pio_sm_set_enabled(pio, sm, true);
120 }


We can also use the PIO assembler to generate a table of instructions for passing through the FIFO, for
Start/Stop/Restart conditions.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/i2c/i2c.pio Lines 125 - 135


125 .program set_scl_sda
126 .side_set 1 opt
127
128 ; Assemble a table of instructions which software can select from, and pass
129 ; into the FIFO, to issue START/STOP/RSTART. This isn't intended to be run as
130 ; a complete program.
131
132 set pindirs, 0 side 0 [7] ; SCL = 0, SDA = 0
133 set pindirs, 1 side 0 [7] ; SCL = 0, SDA = 1
134 set pindirs, 0 side 1 [7] ; SCL = 1, SDA = 0
135 set pindirs, 1 side 1 [7] ; SCL = 1, SDA = 1


The example code does blocking software IO on the state machine’s FIFOs, to avoid the extra complexity of setting up
the system DMA. For example, an I2C start condition is enqueued like so:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/i2c/pio_i2c.c Lines 69 - 73


69 void pio_i2c_start(PIO pio, uint sm) {
70 pio_i2c_put_or_err(pio, sm, 1u << PIO_I2C_ICOUNT_LSB); // Escape code for 2 instruction
sequence
71 pio_i2c_put_or_err(pio, sm, set_scl_sda_program_instructions[I2C_SC1_SD0]); // We are
already in idle state, just pull SDA low
72 pio_i2c_put_or_err(pio, sm, set_scl_sda_program_instructions[I2C_SC0_SD0]); // Also
pull clock low so we can present data
73 }


Because I2C can go wrong at so many points, we need to be able to check the error flag asserted by the state machine,
clear the halt and restart it, before asserting a Stop condition and releasing the bus.

3.6. Examples **361**



Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/i2c/pio_i2c.c Lines 15 - 17


15 bool pio_i2c_check_error(PIO pio, uint sm) {
16 return pio_interrupt_get(pio, sm);
17 }


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/i2c/pio_i2c.c Lines 19 - 23


19 void pio_i2c_resume_after_error(PIO pio, uint sm) {
20 pio_sm_drain_tx_fifo(pio, sm);
21 pio_sm_exec(pio, sm, (pio->sm[sm].execctrl & PIO_SM0_EXECCTRL_WRAP_BOTTOM_BITS) >>
PIO_SM0_EXECCTRL_WRAP_BOTTOM_LSB);
22 pio_interrupt_clear(pio, sm);
23 }


We need some higher-level functions to pass correctly-formatted data though the FIFOs and insert Starts, Stops, NAKs
and so on at the correct points. This is enough to present a similar interface to the other hardware I2Cs on RP2040.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/i2c/i2c_bus_scan.c Lines 13 - 42


13 int main() {
14 stdio_init_all();
15
16 PIO pio = pio0;
17 uint sm = 0 ;
18 uint offset = pio_add_program(pio, &i2c_program);
19 i2c_program_init(pio, sm, offset, PIN_SDA, PIN_SCL);
20
21 printf("\nPIO I2C Bus Scan\n");
22 printf(" 0 1 2 3 4 5 6 7 8 9 A B C D E F\n");
23
24 for (int addr = 0 ; addr < ( 1 << 7 ); ++addr) {
25 if (addr % 16 == 0 ) {
26 printf("%02x ", addr);
27 }
28 // Perform a 0-byte read from the probe address. The read function
29 // returns a negative result NAK'd any time other than the last data
30 // byte. Skip over reserved addresses.
31 int result;
32 if (reserved_addr(addr))
33 result = - 1 ;
34 else
35 result = pio_i2c_read_blocking(pio, sm, addr, NULL, 0 );
36
37 printf(result < 0? "." : "@");
38 printf(addr % 16 == 15? "\n" : " ");
39 }
40 printf("Done.\n");
41 return 0 ;
42 }

**3.6.8. PWM**

3.6. Examples **362**


_Figure 56. Pulse width
modulation (PWM).
The state machine
outputs positive
voltage pulses at
regular intervals. The
width of these pulses
is controlled, so that
the line is high for
some controlled
fraction of the time
(the duty cycle). One
use of this is to
smoothly vary the
brightness of an LED,
by pulsing it faster
than human
persistence of vision._


This program repeatedly counts down to 0 with the Y register, whilst comparing the Y count to a pulse width held in the
X register. The output is asserted low before counting begins, and asserted high when the value in Y reaches X. Once Y
reaches 0, the process repeats, and the output is once more driven low. The fraction of time that the output is high is
therefore proportional to the pulse width stored in X.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/pwm/pwm.pio Lines 9 - 21


$00A09 .program pwm
10 .side_set 1 opt
11
12 pull noblock side 0 ; Pull from FIFO to OSR if available, else copy X to OSR.
13 mov x, osr ; Copy most-recently-pulled value back to scratch X
14 mov y, isr ; ISR contains PWM period. Y used as counter.
15 countloop:
16 jmp x!=y noset ; Set pin high if X == Y, keep the two paths length matched
17 jmp skip side 1
18 noset:
19 nop ; Single dummy cycle to keep the two paths the same length
20 skip:
21 jmp y-- countloop ; Loop until Y hits 0, then pull a fresh PWM value from FIFO


Often, a PWM can be left at a particular pulse width for thousands of pulses, rather than supplying a new pulse width
each time. This example highlights how a nonblocking PULL (Section 3.4.7) can achieve this: if the TX FIFO is empty, a
nonblocking PULL will copy X to the OSR. After pulling, the program copies the OSR into X, so that it can be compared to
the count value in Y. The net effect is that, if a new duty cycle value has not been supplied through the TX FIFO at the
start of this period, the duty cycle from the previous period (which has been copied from X to OSR via the failed PULL, and
then back to X via the MOV) is reused , for as many periods as necessary.
Another useful technique shown here is using the ISR as a configuration register, if IN instructions are not required.
System software can load an arbitrary 32-bit value into the ISR (by executing instructions directly on the state machine),
and the program will copy this value into Y each time it begins counting. The ISR can be used to configure the range of
PWM counting, and the state machine’s clock divider controls the rate of counting.
To start modulating some pulses, we first need to map the state machine’s side-set pins to the GPIO we want to output
PWM on, and tell the state machine where the program is loaded in the PIO instruction memory:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/pwm/pwm.pio Lines 24 - 30


24 static inline void pwm_program_init(PIO pio, uint sm, uint offset, uint pin) {
25 pio_gpio_init(pio, pin);
26 pio_sm_set_consecutive_pindirs(pio, sm, pin, 1 , true);
27 pio_sm_config c = pwm_program_get_default_config(offset);
28 sm_config_set_sideset_pins(&c, pin);
29 pio_sm_init(pio, sm, offset, &c);
30 }


A little footwork is required to load the ISR with the desired counting range:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/pwm/pwm.c Lines 14 - 20


14 void pio_pwm_set_period(PIO pio, uint sm, uint32_t period) {
15 pio_sm_set_enabled(pio, sm, false);
16 pio_sm_put_blocking(pio, sm, period);
17 pio_sm_exec(pio, sm, pio_encode_pull(false, false));

3.6. Examples **363**



18 pio_sm_exec(pio, sm, pio_encode_out(pio_isr, 32 ));
19 pio_sm_set_enabled(pio, sm, true);
20 }


Once this is done, the state machine can be enabled, and PWM values written directly to its TX FIFO.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/pwm/pwm.c Lines 23 - 25


23 void pio_pwm_set_level(PIO pio, uint sm, uint32_t level) {
24 pio_sm_put_blocking(pio, sm, level);
25 }


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/pwm/pwm.c Lines 27 - 51


27 int main() {
28 stdio_init_all();
29 #ifndef PICO_DEFAULT_LED_PIN
30 #warning pio/pwm example requires a board with a regular LED
31 puts("Default LED pin was not defined");
32 #else
33
34 // todo get free sm
35 PIO pio = pio0;
36 int sm = 0 ;
37 uint offset = pio_add_program(pio, &pwm_program);
38 printf("Loaded program at %d\n", offset);
39
40 pwm_program_init(pio, sm, offset, PICO_DEFAULT_LED_PIN);
41 pio_pwm_set_period(pio, sm, (1u << 16 ) - 1 );
42
43 int level = 0 ;
44 while (true) {
45 printf("Level = %d\n", level);
46 pio_pwm_set_level(pio, sm, level * level);
47 level = (level + 1 ) % 256 ;
48 sleep_ms( 10 );
49 }
50 #endif
51 }


If the TX FIFO is kept topped up with fresh pulse width values, this program will consume a new pulse width for each
pulse. Once the FIFO runs dry, the program will again start reusing the most recently supplied value.

**3.6.9. Addition**


Although not designed for computation, PIO is quite likely Turing-complete, provided a long enough piece of tape can be
found. It is conjectured that it could run DOOM, given a sufficiently high clock speed.


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/addition/addition.pio Lines 7 - 25


$00A07 .program addition
$00A08
$00A09 ; Pop two 32 bit integers from the TX FIFO, add them together, and push the
10 ; result to the TX FIFO. Autopush/pull should be disabled as we're using
11 ; explicit push and pull instructions.
12 ;

3.6. Examples **364**



13 ; This program uses the two's complement identity x + y == ~(~x - y)
14
15 pull
16 mov x, ~osr
17 pull
18 mov y, osr
19 jmp test ; this loop is equivalent to the following C code:
20 incr: ; while (y--)
21 jmp x-- test ; x--;
22 test: ; This has the effect of subtracting y from x, eventually.
23 jmp y-- incr
24 mov isr, ~x
25 push


A full 32-bit addition takes only around one minute at 125MHz. The program pulls two numbers from the TX FIFO and
pushes their sum to the RX FIFO, which is perfect for use either with the system DMA, or directly by the processor:


Pico Examples: https://github.com/raspberrypi/pico-examples/blob/master/pio/addition/addition.c


$00A01 /**
$00A02 * Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
$00A03 *
$00A04 * SPDX-License-Identifier: BSD-3-Clause
$00A05 */
$00A06
$00A07 #include <stdlib.h>
$00A08 #include <stdio.h>
$00A09
10 #include "pico/stdlib.h"
11 #include "hardware/pio.h"
12 #include "addition.pio.h"
13
14 // Pop quiz: how many additions does the processor do when calling this function
15 uint32_t do_addition(PIO pio, uint sm, uint32_t a, uint32_t b) {
16 pio_sm_put_blocking(pio, sm, a);
17 pio_sm_put_blocking(pio, sm, b);
18 return pio_sm_get_blocking(pio, sm);
19 }
20
21 int main() {
22 stdio_init_all();
23
24 PIO pio = pio0;
25 uint sm = 0 ;
26 uint offset = pio_add_program(pio, &addition_program);
27 addition_program_init(pio, sm, offset);
28
29 printf("Doing some random additions:\n");
30 for (int i = 0 ; i < 10 ; ++i) {
31 uint a = rand() % 100 ;
32 uint b = rand() % 100 ;
33 printf("%u + %u = %u\n", a, b, do_addition(pio, sm, a, b));
34 }
35 }

**3.6.10. Further Examples**


The Raspberry Pi Pico C/C++ SDK book has a PIO chapter which goes into depth on some software-centric topics not
presented here. It includes a PIO + DMA logic analyser example that can sample every GPIO on every cycle (a bandwidth

3.6. Examples **365**



of nearly 4Gbps at 125MHz, although this does fill up RP2040’s RAM quite quickly).
There are also further examples in the pio/ directory in the Pico Examples repository.
Some of the more experimental example code, such as DPI and SD card support, is currently located in the Pico Extras
and Pico Playground repositories. The PIO parts of these are functional, but the surrounding software stacks are still in
an experimental state.

**3.7. List of Registers**


The PIO0 and PIO1 registers start at base addresses of 0x50200000 and 0x50300000 respectively (defined as PIO0_BASE
and PIO1_BASE in SDK).

_Table 366. List of PIO
registers_ **Offset Name Info**
0x000 CTRL PIO control register


0x004 FSTAT FIFO status register


0x008 FDEBUG FIFO debug register


0x00c FLEVEL FIFO levels
0x010 TXF0 Direct write access to the TX FIFO for this state machine. Each
write pushes one word to the FIFO. Attempting to write to a full
FIFO has no effect on the FIFO state or contents, and sets the
sticky FDEBUG_TXOVER error flag for this FIFO.
0x014 TXF1 Direct write access to the TX FIFO for this state machine. Each
write pushes one word to the FIFO. Attempting to write to a full
FIFO has no effect on the FIFO state or contents, and sets the
sticky FDEBUG_TXOVER error flag for this FIFO.


0x018 TXF2 Direct write access to the TX FIFO for this state machine. Each
write pushes one word to the FIFO. Attempting to write to a full
FIFO has no effect on the FIFO state or contents, and sets the
sticky FDEBUG_TXOVER error flag for this FIFO.


0x01c TXF3 Direct write access to the TX FIFO for this state machine. Each
write pushes one word to the FIFO. Attempting to write to a full
FIFO has no effect on the FIFO state or contents, and sets the
sticky FDEBUG_TXOVER error flag for this FIFO.


0x020 RXF0 Direct read access to the RX FIFO for this state machine. Each
read pops one word from the FIFO. Attempting to read from an
empty FIFO has no effect on the FIFO state, and sets the sticky
FDEBUG_RXUNDER error flag for this FIFO. The data returned to
the system on a read from an empty FIFO is undefined.


0x024 RXF1 Direct read access to the RX FIFO for this state machine. Each
read pops one word from the FIFO. Attempting to read from an
empty FIFO has no effect on the FIFO state, and sets the sticky
FDEBUG_RXUNDER error flag for this FIFO. The data returned to
the system on a read from an empty FIFO is undefined.


0x028 RXF2 Direct read access to the RX FIFO for this state machine. Each
read pops one word from the FIFO. Attempting to read from an
empty FIFO has no effect on the FIFO state, and sets the sticky
FDEBUG_RXUNDER error flag for this FIFO. The data returned to
the system on a read from an empty FIFO is undefined.

3.7. List of Registers **366**



Offset Name Info


0x02c RXF3 Direct read access to the RX FIFO for this state machine. Each
read pops one word from the FIFO. Attempting to read from an
empty FIFO has no effect on the FIFO state, and sets the sticky
FDEBUG_RXUNDER error flag for this FIFO. The data returned to
the system on a read from an empty FIFO is undefined.


0x030 IRQ State machine IRQ flags register. Write 1 to clear. There are 8
state machine IRQ flags, which can be set, cleared, and waited on
by the state machines. There’s no fixed association between
flags and state machines $2014 any state machine can use any flag.


Any of the 8 flags can be used for timing synchronisation
between state machines, using IRQ and WAIT instructions. The
lower four of these flags are also routed out to system-level
interrupt requests, alongside FIFO status interrupts $2014 see e.g.
IRQ0_INTE.
0x034 IRQ_FORCE Writing a 1 to each of these bits will forcibly assert the
corresponding IRQ. Note this is different to the INTF register:
writing here affects PIO internal state. INTF just asserts the
processor-facing IRQ signal for testing ISRs, and is not visible to
the state machines.


0x038 INPUT_SYNC_BYPASS There is a 2-flipflop synchronizer on each GPIO input, which
protects PIO logic from metastabilities. This increases input
delay, and for fast synchronous IO (e.g. SPI) these synchronizers
may need to be bypassed. Each bit in this register corresponds
to one GPIO.
0 → input is synchronized (default)
1 → synchronizer is bypassed
If in doubt, leave this register as all zeroes.


0x03c DBG_PADOUT Read to sample the pad output values PIO is currently driving to
the GPIOs. On RP2040 there are 30 GPIOs, so the two most
significant bits are hardwired to 0.


0x040 DBG_PADOE Read to sample the pad output enables (direction) PIO is
currently driving to the GPIOs. On RP2040 there are 30 GPIOs, so
the two most significant bits are hardwired to 0.
0x044 DBG_CFGINFO The PIO hardware has some free parameters that may vary
between chip products.
These should be provided in the chip datasheet, but are also
exposed here.
0x048 INSTR_MEM0 Write-only access to instruction memory location 0


0x04c INSTR_MEM1 Write-only access to instruction memory location 1


0x050 INSTR_MEM2 Write-only access to instruction memory location 2


0x054 INSTR_MEM3 Write-only access to instruction memory location 3
0x058 INSTR_MEM4 Write-only access to instruction memory location 4


0x05c INSTR_MEM5 Write-only access to instruction memory location 5


0x060 INSTR_MEM6 Write-only access to instruction memory location 6


0x064 INSTR_MEM7 Write-only access to instruction memory location 7

3.7. List of Registers **367**



Offset Name Info


0x068 INSTR_MEM8 Write-only access to instruction memory location 8
0x06c INSTR_MEM9 Write-only access to instruction memory location 9


0x070 INSTR_MEM10 Write-only access to instruction memory location 10


0x074 INSTR_MEM11 Write-only access to instruction memory location 11


0x078 INSTR_MEM12 Write-only access to instruction memory location 12


0x07c INSTR_MEM13 Write-only access to instruction memory location 13
0x080 INSTR_MEM14 Write-only access to instruction memory location 14


0x084 INSTR_MEM15 Write-only access to instruction memory location 15


0x088 INSTR_MEM16 Write-only access to instruction memory location 16


0x08c INSTR_MEM17 Write-only access to instruction memory location 17


0x090 INSTR_MEM18 Write-only access to instruction memory location 18
0x094 INSTR_MEM19 Write-only access to instruction memory location 19


0x098 INSTR_MEM20 Write-only access to instruction memory location 20


0x09c INSTR_MEM21 Write-only access to instruction memory location 21


0x0a0 INSTR_MEM22 Write-only access to instruction memory location 22
0x0a4 INSTR_MEM23 Write-only access to instruction memory location 23


0x0a8 INSTR_MEM24 Write-only access to instruction memory location 24


0x0ac INSTR_MEM25 Write-only access to instruction memory location 25


0x0b0 INSTR_MEM26 Write-only access to instruction memory location 26


0x0b4 INSTR_MEM27 Write-only access to instruction memory location 27
0x0b8 INSTR_MEM28 Write-only access to instruction memory location 28


0x0bc INSTR_MEM29 Write-only access to instruction memory location 29


0x0c0 INSTR_MEM30 Write-only access to instruction memory location 30


0x0c4 INSTR_MEM31 Write-only access to instruction memory location 31


0x0c8 SM0_CLKDIV Clock divisor register for state machine 0
Frequency = clock freq / (CLKDIV_INT + CLKDIV_FRAC / 256)


0x0cc SM0_EXECCTRL Execution/behavioural settings for state machine 0
0x0d0 SM0_SHIFTCTRL Control behaviour of the input/output shift registers for state
machine 0


0x0d4 SM0_ADDR Current instruction address of state machine 0
0x0d8 SM0_INSTR Read to see the instruction currently addressed by state machine
0’s program counter
Write to execute an instruction immediately (including jumps)
and then resume execution.
0x0dc SM0_PINCTRL State machine pin control


0x0e0 SM1_CLKDIV Clock divisor register for state machine 1
Frequency = clock freq / (CLKDIV_INT + CLKDIV_FRAC / 256)
0x0e4 SM1_EXECCTRL Execution/behavioural settings for state machine 1

3.7. List of Registers **368**



Offset Name Info


0x0e8 SM1_SHIFTCTRL Control behaviour of the input/output shift registers for state
machine 1


0x0ec SM1_ADDR Current instruction address of state machine 1


0x0f0 SM1_INSTR Read to see the instruction currently addressed by state machine
1’s program counter
Write to execute an instruction immediately (including jumps)
and then resume execution.


0x0f4 SM1_PINCTRL State machine pin control
0x0f8 SM2_CLKDIV Clock divisor register for state machine 2
Frequency = clock freq / (CLKDIV_INT + CLKDIV_FRAC / 256)


0x0fc SM2_EXECCTRL Execution/behavioural settings for state machine 2
0x100 SM2_SHIFTCTRL Control behaviour of the input/output shift registers for state
machine 2


0x104 SM2_ADDR Current instruction address of state machine 2
0x108 SM2_INSTR Read to see the instruction currently addressed by state machine
2’s program counter
Write to execute an instruction immediately (including jumps)
and then resume execution.


0x10c SM2_PINCTRL State machine pin control


0x110 SM3_CLKDIV Clock divisor register for state machine 3
Frequency = clock freq / (CLKDIV_INT + CLKDIV_FRAC / 256)


0x114 SM3_EXECCTRL Execution/behavioural settings for state machine 3


0x118 SM3_SHIFTCTRL Control behaviour of the input/output shift registers for state
machine 3


0x11c SM3_ADDR Current instruction address of state machine 3


0x120 SM3_INSTR Read to see the instruction currently addressed by state machine
3’s program counter
Write to execute an instruction immediately (including jumps)
and then resume execution.


0x124 SM3_PINCTRL State machine pin control


0x128 INTR Raw Interrupts


0x12c IRQ0_INTE Interrupt Enable for irq0
0x130 IRQ0_INTF Interrupt Force for irq0


0x134 IRQ0_INTS Interrupt status after masking & forcing for irq0


0x138 IRQ1_INTE Interrupt Enable for irq1


0x13c IRQ1_INTF Interrupt Force for irq1
0x140 IRQ1_INTS Interrupt status after masking & forcing for irq1

**PIO: CTRL Register**


Offset : 0x000

3.7. List of Registers **369**



Description
PIO control register

_Table 367. CTRL
Register_ **Bits Name Description Type Reset**
31:12 Reserved. - - -


11:8 CLKDIV_RESTART Restart a state machine’s clock divider from an initial
phase of 0. Clock dividers are free-running, so once
started, their output (including fractional jitter) is
completely determined by the integer/fractional divisor
configured in SMx_CLKDIV. This means that, if multiple
clock dividers with the same divisor are restarted
simultaneously, by writing multiple 1 bits to this field, the
execution clocks of those state machines will run in
precise lockstep.


Note that setting/clearing SM_ENABLE does not stop the
clock divider from running, so once multiple state
machines' clocks are synchronised, it is safe to
disable/reenable a state machine, whilst keeping the clock
dividers in sync.


Note also that CLKDIV_RESTART can be written to whilst
the state machine is running, and this is useful to
resynchronise clock dividers after the divisors
(SMx_CLKDIV) have been changed on-the-fly.


SC 0x0


7:4 SM_RESTART Write 1 to instantly clear internal SM state which may be
otherwise difficult to access and will affect future
execution.


Specifically, the following are cleared: input and output
shift counters; the contents of the input shift register; the
delay counter; the waiting-on-IRQ state; any stalled
instruction written to SMx_INSTR or run by OUT/MOV
EXEC; any pin write left asserted due to OUT_STICKY.


The program counter, the contents of the output shift
register and the X/Y scratch registers are not affected.


SC 0x0


3:0 SM_ENABLE Enable/disable each of the four state machines by writing
1/0 to each of these four bits. When disabled, a state
machine will cease executing instructions, except those
written directly to SMx_INSTR by the system. Multiple bits
can be set/cleared at once to run/halt multiple state
machines simultaneously.


RW 0x0

**PIO: FSTAT Register**


Offset : 0x004
Description
FIFO status register

_Table 368. FSTAT
Register_ **Bits Name Description Type Reset**
31:28 Reserved. - - -

3.7. List of Registers **370**



Bits Name Description Type Reset


27:24 TXEMPTY State machine TX FIFO is empty RO 0xf
23:20 Reserved. - - -


19:16 TXFULL State machine TX FIFO is full RO 0x0


15:12 Reserved. - - -


11:8 RXEMPTY State machine RX FIFO is empty RO 0xf


7:4 Reserved. - - -
3:0 RXFULL State machine RX FIFO is full RO 0x0

**PIO: FDEBUG Register**


Offset : 0x008
Description
FIFO debug register

_Table 369. FDEBUG
Register_ **Bits Name Description Type Reset**
31:28 Reserved. - - -


27:24 TXSTALL State machine has stalled on empty TX FIFO during a
blocking PULL, or an OUT with autopull enabled. Write 1 to
clear.


WC 0x0


23:20 Reserved. - - -


19:16 TXOVER TX FIFO overflow (i.e. write-on-full by the system) has
occurred. Write 1 to clear. Note that write-on-full does not
alter the state or contents of the FIFO in any way, but the
data that the system attempted to write is dropped, so if
this flag is set, your software has quite likely dropped
some data on the floor.


WC 0x0


15:12 Reserved. - - -


11:8 RXUNDER RX FIFO underflow (i.e. read-on-empty by the system) has
occurred. Write 1 to clear. Note that read-on-empty does
not perturb the state of the FIFO in any way, but the data
returned by reading from an empty FIFO is undefined, so
this flag generally only becomes set due to some kind of
software error.


WC 0x0


7:4 Reserved. - - -


3:0 RXSTALL State machine has stalled on full RX FIFO during a
blocking PUSH, or an IN with autopush enabled. This flag
is also set when a nonblocking PUSH to a full FIFO took
place, in which case the state machine has dropped data.
Write 1 to clear.


WC 0x0

**PIO: FLEVEL Register**


Offset : 0x00c
Description
FIFO levels

3.7. List of Registers **371**


_Table 370. FLEVEL
Register_
**Bits Name Description Type Reset**


31:28 RX3 RO 0x0
27:24 TX3 RO 0x0


23:20 RX2 RO 0x0


19:16 TX2 RO 0x0


15:12 RX1 RO 0x0


11:8 TX1 RO 0x0
7:4 RX0 RO 0x0


3:0 TX0 RO 0x0

**PIO: TXF0, TXF1, TXF2, TXF3 Registers**


Offsets : 0x010, 0x014, 0x018, 0x01c

_Table 371. TXF0,
TXF1, TXF2, TXF3
Registers_


Bits Description Type Reset
31:0 Direct write access to the TX FIFO for this state machine. Each write pushes
one word to the FIFO. Attempting to write to a full FIFO has no effect on the
FIFO state or contents, and sets the sticky FDEBUG_TXOVER error flag for this
FIFO.


WF 0x00000000

**PIO: RXF0, RXF1, RXF2, RXF3 Registers**


Offsets : 0x020, 0x024, 0x028, 0x02c

_Table 372. RXF0,
RXF1, RXF2, RXF3
Registers_


Bits Description Type Reset
31:0 Direct read access to the RX FIFO for this state machine. Each read pops one
word from the FIFO. Attempting to read from an empty FIFO has no effect on
the FIFO state, and sets the sticky FDEBUG_RXUNDER error flag for this FIFO.
The data returned to the system on a read from an empty FIFO is undefined.

### RF -

**PIO: IRQ Register**


Offset : 0x030

_Table 373. IRQ
Register_ **Bits Description Type Reset**
31:8 Reserved. - -


7:0 State machine IRQ flags register. Write 1 to clear. There are 8 state machine
IRQ flags, which can be set, cleared, and waited on by the state machines.
There’s no fixed association between flags and state machines $2014 any state
machine can use any flag.


Any of the 8 flags can be used for timing synchronisation between state
machines, using IRQ and WAIT instructions. The lower four of these flags are
also routed out to system-level interrupt requests, alongside FIFO status
interrupts $2014 see e.g. IRQ0_INTE.


WC 0x00

**PIO: IRQ_FORCE Register**


Offset : 0x034

3.7. List of Registers **372**


_Table 374. IRQ_FORCE
Register_
**Bits Description Type Reset**


31:8 Reserved. - -
7:0 Writing a 1 to each of these bits will forcibly assert the corresponding IRQ.
Note this is different to the INTF register: writing here affects PIO internal
state. INTF just asserts the processor-facing IRQ signal for testing ISRs, and is
not visible to the state machines.


WF 0x00

**PIO: INPUT_SYNC_BYPASS Register**


Offset : 0x038

_Table 375.
INPUT_SYNC_BYPASS
Register_


Bits Description Type Reset
31:0 There is a 2-flipflop synchronizer on each GPIO input, which protects PIO logic
from metastabilities. This increases input delay, and for fast synchronous IO
(e.g. SPI) these synchronizers may need to be bypassed. Each bit in this
register corresponds to one GPIO.
0 → input is synchronized (default)
1 → synchronizer is bypassed
If in doubt, leave this register as all zeroes.


RW 0x00000000

**PIO: DBG_PADOUT Register**


Offset : 0x03c

_Table 376.
DBG_PADOUT Register_
**Bits Description Type Reset**


31:0 Read to sample the pad output values PIO is currently driving to the GPIOs. On
RP2040 there are 30 GPIOs, so the two most significant bits are hardwired to
0.


RO 0x00000000

**PIO: DBG_PADOE Register**


Offset : 0x040

_Table 377.
DBG_PADOE Register_ **Bits Description Type Reset**
31:0 Read to sample the pad output enables (direction) PIO is currently driving to
the GPIOs. On RP2040 there are 30 GPIOs, so the two most significant bits are
hardwired to 0.


RO 0x00000000

**PIO: DBG_CFGINFO Register**


Offset : 0x044
Description
The PIO hardware has some free parameters that may vary between chip products.
These should be provided in the chip datasheet, but are also exposed here.

_Table 378.
DBG_CFGINFO
Register_


Bits Name Description Type Reset
31:22 Reserved. - - -


21:16 IMEM_SIZE The size of the instruction memory, measured in units of
one instruction

### RO -


15:12 Reserved. - - -

3.7. List of Registers **373**



Bits Name Description Type Reset


11:8 SM_COUNT The number of state machines this PIO instance is
equipped with.

### RO -


7:6 Reserved. - - -


5:0 FIFO_DEPTH The depth of the state machine TX/RX FIFOs, measured in
words.
Joining fifos via SHIFTCTRL_FJOIN gives one FIFO with
double
this depth.

### RO -

**PIO: INSTR_MEM0, INSTR_MEM1, ..., INSTR_MEM30, INSTR_MEM31 Registers**


Offsets : 0x048, 0x04c, ..., 0x0c0, 0x0c4

_Table 379.
INSTR_MEM0,
INSTR_MEM1, ...,
INSTR_MEM30,
INSTR_MEM31
Registers_


Bits Description Type Reset
31:16 Reserved. - -


15:0 Write-only access to instruction memory location N WO 0x0000

**PIO: SM0_CLKDIV, SM1_CLKDIV, SM2_CLKDIV, SM3_CLKDIV Registers**


Offsets : 0x0c8, 0x0e0, 0x0f8, 0x110
Description
Clock divisor register for state machine N
Frequency = clock freq / (CLKDIV_INT + CLKDIV_FRAC / 256)

_Table 380.
SM0_CLKDIV,
SM1_CLKDIV,
SM2_CLKDIV,
SM3_CLKDIV
Registers_


Bits Name Description Type Reset


31:16 INT Effective frequency is sysclk/(int + frac/256).
Value of 0 is interpreted as 65536. If INT is 0, FRAC must
also be 0.


RW 0x0001


15:8 FRAC Fractional part of clock divisor RW 0x00


7:0 Reserved. - - -


PIO: SM0_EXECCTRL, SM1_EXECCTRL, SM2_EXECCTRL, SM3_EXECCTRL
Registers


Offsets : 0x0cc, 0x0e4, 0x0fc, 0x114


Description
Execution/behavioural settings for state machine N

_Table 381.
SM0_EXECCTRL,
SM1_EXECCTRL,
SM2_EXECCTRL,
SM3_EXECCTRL
Registers_


Bits Name Description Type Reset


31 EXEC_STALLED If 1, an instruction written to SMx_INSTR is stalled, and
latched by the state machine. Will clear to 0 once this
instruction completes.


RO 0x0


30 SIDE_EN If 1, the MSB of the Delay/Side-set instruction field is used
as side-set enable, rather than a side-set data bit. This
allows instructions to perform side-set optionally, rather
than on every instruction, but the maximum possible side-
set width is reduced from 5 to 4. Note that the value of
PINCTRL_SIDESET_COUNT is inclusive of this enable bit.


RW 0x0

3.7. List of Registers **374**



Bits Name Description Type Reset


29 SIDE_PINDIR If 1, side-set data is asserted to pin directions, instead of
pin values


RW 0x0


28:24 JMP_PIN The GPIO number to use as condition for JMP PIN.
Unaffected by input mapping.


RW 0x00


23:19 OUT_EN_SEL Which data bit to use for inline OUT enable RW 0x00


18 INLINE_OUT_EN If 1, use a bit of OUT data as an auxiliary write enable
When used in conjunction with OUT_STICKY, writes with
an enable of 0 will
deassert the latest pin write. This can create useful
masking/override behaviour
due to the priority ordering of state machine pin writes
(SM0 < SM1 < ...)


RW 0x0


17 OUT_STICKY Continuously assert the most recent OUT/SET to the pins RW 0x0


16:12 WRAP_TOP After reaching this address, execution is wrapped to
wrap_bottom.
If the instruction is a jump, and the jump condition is true,
the jump takes priority.


RW 0x1f


11:7 WRAP_BOTTOM After reaching wrap_top, execution is wrapped to this
address.


RW 0x00


6:5 Reserved. - - -


4 STATUS_SEL Comparison used for the MOV x, STATUS instruction.
0x0 → All-ones if TX FIFO level < N, otherwise all-zeroes
0x1 → All-ones if RX FIFO level < N, otherwise all-zeroes


RW 0x0


3:0 STATUS_N Comparison level for the MOV x, STATUS instruction RW 0x0


PIO: SM0_SHIFTCTRL, SM1_SHIFTCTRL, SM2_SHIFTCTRL, SM3_SHIFTCTRL
Registers


Offsets : 0x0d0, 0x0e8, 0x100, 0x118
Description
Control behaviour of the input/output shift registers for state machine N

_Table 382.
SM0_SHIFTCTRL,
SM1_SHIFTCTRL,
SM2_SHIFTCTRL,
SM3_SHIFTCTRL
Registers_


Bits Name Description Type Reset
31 FJOIN_RX When 1, RX FIFO steals the TX FIFO’s storage, and
becomes twice as deep.
TX FIFO is disabled as a result (always reads as both full
and empty).
FIFOs are flushed when this bit is changed.


RW 0x0


30 FJOIN_TX When 1, TX FIFO steals the RX FIFO’s storage, and
becomes twice as deep.
RX FIFO is disabled as a result (always reads as both full
and empty).
FIFOs are flushed when this bit is changed.


RW 0x0


29:25 PULL_THRESH Number of bits shifted out of OSR before autopull, or
conditional pull (PULL IFEMPTY), will take place.
Write 0 for value of 32.


RW 0x00

3.7. List of Registers **375**



Bits Name Description Type Reset


24:20 PUSH_THRESH Number of bits shifted into ISR before autopush, or
conditional push (PUSH IFFULL), will take place.
Write 0 for value of 32.


RW 0x00


19 OUT_SHIFTDIR 1 = shift out of output shift register to right. 0 = to left. RW 0x1


18 IN_SHIFTDIR 1 = shift input shift register to right (data enters from left).
0 = to left.


RW 0x1


17 AUTOPULL Pull automatically when the output shift register is
emptied, i.e. on or following an OUT instruction which
causes the output shift counter to reach or exceed
PULL_THRESH.


RW 0x0


16 AUTOPUSH Push automatically when the input shift register is filled,
i.e. on an IN instruction which causes the input shift
counter to reach or exceed PUSH_THRESH.


RW 0x0


15:0 Reserved. - - -

**PIO: SM0_ADDR, SM1_ADDR, SM2_ADDR, SM3_ADDR Registers**


Offsets : 0x0d4, 0x0ec, 0x104, 0x11c

_Table 383. SM0_ADDR,
SM1_ADDR,
SM2_ADDR,
SM3_ADDR Registers_


Bits Description Type Reset
31:5 Reserved. - -


4:0 Current instruction address of state machine N RO 0x00

**PIO: SM0_INSTR, SM1_INSTR, SM2_INSTR, SM3_INSTR Registers**


Offsets : 0x0d8, 0x0f0, 0x108, 0x120

_Table 384.
SM0_INSTR,
SM1_INSTR,
SM2_INSTR,
SM3_INSTR Registers_


Bits Description Type Reset
31:16 Reserved. - -


15:0 Read to see the instruction currently addressed by state machine N 's program
counter.
Write to execute an instruction immediately (including jumps) and then
resume execution.

### RW -

**PIO: SM0_PINCTRL, SM1_PINCTRL, SM2_PINCTRL, SM3_PINCTRL Registers**


Offsets : 0x0dc, 0x0f4, 0x10c, 0x124
Description
State machine pin control

_Table 385.
SM0_PINCTRL,
SM1_PINCTRL,
SM2_PINCTRL,
SM3_PINCTRL
Registers_


Bits Name Description Type Reset
31:29 SIDESET_COUNT The number of MSBs of the Delay/Side-set instruction
field which are used for side-set. Inclusive of the enable
bit, if present. Minimum of 0 (all delay bits, no side-set)
and maximum of 5 (all side-set, no delay).


RW 0x0


28:26 SET_COUNT The number of pins asserted by a SET. In the range 0 to 5
inclusive.


RW 0x5

3.7. List of Registers **376**



Bits Name Description Type Reset


25:20 OUT_COUNT The number of pins asserted by an OUT PINS, OUT
PINDIRS or MOV PINS instruction. In the range 0 to 32
inclusive.


RW 0x00


19:15 IN_BASE The pin which is mapped to the least-significant bit of a
state machine’s IN data bus. Higher-numbered pins are
mapped to consecutively more-significant data bits, with a
modulo of 32 applied to pin number.


RW 0x00


14:10 SIDESET_BASE The lowest-numbered pin that will be affected by a side-
set operation. The MSBs of an instruction’s side-set/delay
field (up to 5, determined by SIDESET_COUNT) are used
for side-set data, with the remaining LSBs used for delay.
The least-significant bit of the side-set portion is the bit
written to this pin, with more-significant bits written to
higher-numbered pins.


RW 0x00


9:5 SET_BASE The lowest-numbered pin that will be affected by a SET
PINS or SET PINDIRS instruction. The data written to this
pin is the least-significant bit of the SET data.


RW 0x00


4:0 OUT_BASE The lowest-numbered pin that will be affected by an OUT
PINS, OUT PINDIRS or MOV PINS instruction. The data
written to this pin will always be the least-significant bit of
the OUT or MOV data.


RW 0x00

**PIO: INTR Register**


Offset : 0x128


Description
Raw Interrupts

_Table 386. INTR
Register_
**Bits Name Description Type Reset**


31:12 Reserved. - - -
11 SM3 RO 0x0


10 SM2 RO 0x0


9 SM1 RO 0x0


8 SM0 RO 0x0


7 SM3_TXNFULL RO 0x0
6 SM2_TXNFULL RO 0x0


5 SM1_TXNFULL RO 0x0


4 SM0_TXNFULL RO 0x0


3 SM3_RXNEMPTY RO 0x0
2 SM2_RXNEMPTY RO 0x0


1 SM1_RXNEMPTY RO 0x0


0 SM0_RXNEMPTY RO 0x0

**PIO: IRQ0_INTE Register**

3.7. List of Registers **377**



Offset : 0x12c
Description
Interrupt Enable for irq0

_Table 387. IRQ0_INTE
Register_ **Bits Name Description Type Reset**
31:12 Reserved. - - -


11 SM3 RW 0x0
10 SM2 RW 0x0


9 SM1 RW 0x0


8 SM0 RW 0x0


7 SM3_TXNFULL RW 0x0


6 SM2_TXNFULL RW 0x0
5 SM1_TXNFULL RW 0x0


4 SM0_TXNFULL RW 0x0


3 SM3_RXNEMPTY RW 0x0


2 SM2_RXNEMPTY RW 0x0
1 SM1_RXNEMPTY RW 0x0


0 SM0_RXNEMPTY RW 0x0

**PIO: IRQ0_INTF Register**


Offset : 0x130


Description
Interrupt Force for irq0

_Table 388. IRQ0_INTF
Register_ **Bits Name Description Type Reset**
31:12 Reserved. - - -


11 SM3 RW 0x0
10 SM2 RW 0x0


9 SM1 RW 0x0


8 SM0 RW 0x0


7 SM3_TXNFULL RW 0x0


6 SM2_TXNFULL RW 0x0
5 SM1_TXNFULL RW 0x0


4 SM0_TXNFULL RW 0x0


3 SM3_RXNEMPTY RW 0x0


2 SM2_RXNEMPTY RW 0x0
1 SM1_RXNEMPTY RW 0x0


0 SM0_RXNEMPTY RW 0x0

**PIO: IRQ0_INTS Register**

3.7. List of Registers **378**



Offset : 0x134
Description
Interrupt status after masking & forcing for irq0

_Table 389. IRQ0_INTS
Register_ **Bits Name Description Type Reset**
31:12 Reserved. - - -


11 SM3 RO 0x0
10 SM2 RO 0x0


9 SM1 RO 0x0


8 SM0 RO 0x0


7 SM3_TXNFULL RO 0x0


6 SM2_TXNFULL RO 0x0
5 SM1_TXNFULL RO 0x0


4 SM0_TXNFULL RO 0x0


3 SM3_RXNEMPTY RO 0x0


2 SM2_RXNEMPTY RO 0x0
1 SM1_RXNEMPTY RO 0x0


0 SM0_RXNEMPTY RO 0x0

**PIO: IRQ1_INTE Register**


Offset : 0x138


Description
Interrupt Enable for irq1

_Table 390. IRQ1_INTE
Register_ **Bits Name Description Type Reset**
31:12 Reserved. - - -


11 SM3 RW 0x0
10 SM2 RW 0x0


9 SM1 RW 0x0


8 SM0 RW 0x0


7 SM3_TXNFULL RW 0x0


6 SM2_TXNFULL RW 0x0
5 SM1_TXNFULL RW 0x0


4 SM0_TXNFULL RW 0x0


3 SM3_RXNEMPTY RW 0x0


2 SM2_RXNEMPTY RW 0x0
1 SM1_RXNEMPTY RW 0x0


0 SM0_RXNEMPTY RW 0x0

**PIO: IRQ1_INTF Register**

3.7. List of Registers **379**



Offset : 0x13c
Description
Interrupt Force for irq1

_Table 391. IRQ1_INTF
Register_ **Bits Name Description Type Reset**
31:12 Reserved. - - -


11 SM3 RW 0x0
10 SM2 RW 0x0


9 SM1 RW 0x0


8 SM0 RW 0x0


7 SM3_TXNFULL RW 0x0


6 SM2_TXNFULL RW 0x0
5 SM1_TXNFULL RW 0x0


4 SM0_TXNFULL RW 0x0


3 SM3_RXNEMPTY RW 0x0


2 SM2_RXNEMPTY RW 0x0
1 SM1_RXNEMPTY RW 0x0


0 SM0_RXNEMPTY RW 0x0

**PIO: IRQ1_INTS Register**


Offset : 0x140


Description
Interrupt status after masking & forcing for irq1

_Table 392. IRQ1_INTS
Register_ **Bits Name Description Type Reset**
31:12 Reserved. - - -


11 SM3 RO 0x0
10 SM2 RO 0x0


9 SM1 RO 0x0


8 SM0 RO 0x0


7 SM3_TXNFULL RO 0x0


6 SM2_TXNFULL RO 0x0
5 SM1_TXNFULL RO 0x0


4 SM0_TXNFULL RO 0x0


3 SM3_RXNEMPTY RO 0x0


2 SM2_RXNEMPTY RO 0x0
1 SM1_RXNEMPTY RO 0x0


0 SM0_RXNEMPTY RO 0x0

3.7. List of Registers **380**

