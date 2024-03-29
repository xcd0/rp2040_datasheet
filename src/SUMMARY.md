# Summary

[Top](./index.md)
- [Colophon](./colophon.md)
- [Chapter 1](./chapter_1.md)
- [Chapter 2](./chapter_2.md)
- [Chapter 3](./chapter_3.md)
- [Chapter 4](./chapter_4.md)
- [Chapter 5](./chapter_5.md)
- [Appendix A](./appendix_a.md)
- [Appendix B](./appendix_b.md)
- [Appendix C](./appendix_c.md)
- [Appendix D](./appendix_d.md)


## Table of contents

- [Colophon]()
	- [Legal disclaimer notice]()
- [1. Introduction]()
	- [1.1. Why is the chip called RP2040?]()
	- [1.2. Summary]()
	- [1.3. The Chip]()
	- [1.4. Pinout Reference]()
		- [1.4.1. Pin Locations]()
		- [1.4.2. Pin Descriptions]()
		- [1.4.3. GPIO Functions]()
- [2. System Description]()
	- [2.1. Bus Fabric]()
		- [2.1.1. AHB-Lite Crossbar]()
		- [2.1.2. Atomic Register Access]()
		- [2.1.3. APB Bridge]()
		- [2.1.4. Narrow IO Register Writes]()
		- [2.1.5. List of Registers]()
	- [2.2. Address Map]()
		- [2.2.1. Summary]()
		- [2.2.2. Detail]()
	- [2.3. Processor subsystem]()
		- [2.3.1. SIO]()
		- [2.3.2. Interrupts]()
		- [2.3.3. Event Signals]()
		- [2.3.4. Debug]()
	- [2.4. Cortex-M0+]()
		- [2.4.1. Features]()
		- [2.4.2. Functional Description]()
		- [2.4.3. Programmer’s model]()
		- [2.4.4. System control]()
		- [2.4.5. NVIC]()
		- [2.4.6. MPU]()
		- [2.4.7. Debug]()
		- [2.4.8. List of Registers]()
	- [2.5. DMA]()
		- [2.5.1. Configuring Channels]()
		- [2.5.2. Starting Channels]()
		- [2.5.3. Data Request (DREQ)]()
		- [2.5.4. Interrupts]()
		- [2.5.5. Additional Features]()
		- [2.5.6. Example Use Cases]()
		- [2.5.7. List of Registers]()
	- [2.6. Memory]()
		- [2.6.1. ROM]()
		- [2.6.2. SRAM]()
		- [2.6.3. Flash]()
	- [2.7. Boot Sequence]()
	- [2.8. Bootrom]()
		- [2.8.1. Processor Controlled Boot Sequence]()
		- [2.8.2. Launching Code On Processor Core 1]()
		- [2.8.3. Bootrom Contents]()
		- [2.8.4. USB Mass Storage Interface]()
		- [2.8.5. USB PICOBOOT Interface]()
	- [2.9. Power Supplies]()
		- [2.9.1. Digital IO Supply (IOVDD)]()
- [Table of contents]()
	- [2.9.2. Digital Core Supply (DVDD)]()
	- [2.9.3. On-Chip Voltage Regulator Input Supply (VREG_VIN)]()
	- [2.9.4. USB PHY Supply (USB_VDD)]()
	- [2.9.5. ADC Supply (ADC_AVDD)]()
	- [2.9.6. Power Supply Sequencing]()
	- [2.9.7. Power Supply Schemes]()
- [2.10. Core Supply Regulator]()
	- [2.10.1. Application Circuit]()
	- [2.10.2. Operating Modes]()
	- [2.10.3. Output Voltage Select]()
	- [2.10.4. Status]()
	- [2.10.5. Current Limit]()
	- [2.10.6. List of Registers]()
	- [2.10.7. Detailed Specifications]()
- [2.11. Power Control]()
	- [2.11.1. Top-level Clock Gates]()
	- [2.11.2. SLEEP State]()
	- [2.11.3. DORMANT State]()
	- [2.11.4. Memory Power Down]()
	- [2.11.5. Programmer’s Model]()
- [2.12. Chip-Level Reset]()
	- [2.12.1. Overview]()
	- [2.12.2. Power-on Reset]()
	- [2.12.3. Brown-out Detection]()
	- [2.12.4. Supply Monitor]()
	- [2.12.5. External Reset]()
	- [2.12.6. Rescue Debug Port Reset]()
	- [2.12.7. Source of Last Reset]()
	- [2.12.8. List of Registers]()
- [2.13. Power-On State Machine]()
	- [2.13.1. Overview]()
	- [2.13.2. Power On Sequence]()
	- [2.13.3. Register Control]()
	- [2.13.4. Interaction with Watchdog]()
	- [2.13.5. List of Registers]()
- [2.14. Subsystem Resets]()
	- [2.14.1. Overview]()
	- [2.14.2. Programmer’s Model]()
	- [2.14.3. List of Registers]()
- [2.15. Clocks]()
	- [2.15.1. Overview]()
	- [2.15.2. Clock sources]()
	- [2.15.3. Clock Generators]()
	- [2.15.4. Frequency Counter]()
	- [2.15.5. Resus]()
	- [2.15.6. Programmer’s Model]()
	- [2.15.7. List of Registers]()
- [2.16. Crystal Oscillator (XOSC)]()
	- [2.16.1. Overview]()
	- [2.16.2. Usage]()
	- [2.16.3. Startup Delay]()
	- [2.16.4. XOSC Counter]()
	- [2.16.5. DORMANT mode]()
	- [2.16.6. Programmer’s Model]()
	- [2.16.7. List of Registers]()
- [2.17. Ring Oscillator (ROSC)]()
	- [2.17.1. Overview]()
	- [2.17.2. ROSC/XOSC trade-offs]()
	- [2.17.3. Modifying the frequency]()
	- [2.17.4. ROSC divider]()
- [Table of contents]()
		- [2.17.5. Random Number Generator]()
		- [2.17.6. ROSC Counter]()
		- [2.17.7. DORMANT mode]()
		- [2.17.8. List of Registers]()
	- [2.18. PLL]()
		- [2.18.1. Overview]()
		- [2.18.2. Calculating PLL parameters]()
		- [2.18.3. Configuration]()
		- [2.18.4. List of Registers]()
	- [2.19. GPIO]()
		- [2.19.1. Overview]()
		- [2.19.2. Function Select]()
		- [2.19.3. Interrupts]()
		- [2.19.4. Pads]()
		- [2.19.5. Software Examples]()
		- [2.19.6. List of Registers]()
	- [2.20. Sysinfo]()
		- [2.20.1. Overview]()
		- [2.20.2. List of Registers]()
	- [2.21. Syscfg]()
		- [2.21.1. Overview]()
		- [2.21.2. List of Registers]()
	- [2.22. TBMAN]()
		- [2.22.1. List of Registers]()
- [3. PIO]()
	- [3.1. Overview]()
	- [3.2. Programmer’s Model]()
		- [3.2.1. PIO Programs]()
		- [3.2.2. Control Flow]()
		- [3.2.3. Registers]()
		- [3.2.4. Stalling]()
		- [3.2.5. Pin Mapping]()
		- [3.2.6. IRQ Flags]()
		- [3.2.7. Interactions Between State Machines]()
	- [3.3. PIO Assembler (pioasm)]()
		- [3.3.1. Directives]()
		- [3.3.2. Values]()
		- [3.3.3. Expressions]()
		- [3.3.4. Comments]()
		- [3.3.5. Labels]()
		- [3.3.6. Instructions]()
		- [3.3.7. Pseudoinstructions]()
	- [3.4. Instruction Set]()
		- [3.4.1. Summary]()
		- [3.4.2. JMP]()
		- [3.4.3. WAIT]()
		- [3.4.4. IN]()
		- [3.4.5. OUT]()
		- [3.4.6. PUSH]()
		- [3.4.7. PULL]()
		- [3.4.8. MOV]()
		- [3.4.9. IRQ]()
		- [3.4.10. SET]()
	- [3.5. Functional Details]()
		- [3.5.1. Side-set]()
		- [3.5.2. Program Wrapping]()
		- [3.5.3. FIFO Joining]()
		- [3.5.4. Autopush and Autopull]()
		- [3.5.5. Clock Dividers]()
		- [3.5.6. GPIO Mapping]()
- [Table of contents]()
		- [3.5.7. Forced and EXEC’d Instructions]()
	- [3.6. Examples]()
		- [3.6.1. Duplex SPI]()
		- [3.6.2. WS2812 LEDs]()
		- [3.6.3. UART TX]()
		- [3.6.4. UART RX]()
		- [3.6.5. Manchester Serial TX and RX]()
		- [3.6.6. Differential Manchester (BMC) TX and RX]()
		- [3.6.7. I2C]()
		- [3.6.8. PWM]()
		- [3.6.9. Addition]()
		- [3.6.10. Further Examples]()
	- [3.7. List of Registers]()
- [4. Peripherals]()
	- [4.1. USB]()
		- [4.1.1. Overview]()
		- [4.1.2. Architecture]()
		- [4.1.3. Programmer’s Model]()
		- [4.1.4. List of Registers]()
		- [References]()
	- [4.2. UART]()
		- [4.2.1. Overview]()
		- [4.2.2. Functional description]()
		- [4.2.3. Operation]()
		- [4.2.4. UART hardware flow control]()
		- [4.2.5. UART DMA Interface]()
		- [4.2.6. Interrupts]()
		- [4.2.7. Programmer’s Model]()
		- [4.2.8. List of Registers]()
	- [4.3. I2C]()
		- [4.3.1. Features]()
		- [4.3.2. IP Configuration]()
		- [4.3.3. I2C Overview]()
		- [4.3.4. I2C Terminology]()
		- [4.3.5. I2C Behaviour]()
		- [4.3.6. I2C Protocols]()
		- [4.3.7. Tx FIFO Management and START, STOP and RESTART Generation]()
		- [4.3.8. Multiple Master Arbitration]()
		- [4.3.9. Clock Synchronization]()
		- [4.3.10. Operation Modes]()
		- [4.3.11. Spike Suppression]()
		- [4.3.12. Fast Mode Plus Operation]()
		- [4.3.13. Bus Clear Feature]()
		- [4.3.14. IC_CLK Frequency Configuration]()
		- [4.3.15. DMA Controller Interface]()
		- [4.3.16. Operation of Interrupt Registers]()
		- [4.3.17. List of Registers]()
	- [4.4. SPI]()
		- [4.4.1. Overview]()
		- [4.4.2. Functional Description]()
		- [4.4.3. Operation]()
		- [4.4.4. List of Registers]()
	- [4.5. PWM]()
		- [4.5.1. Overview]()
		- [4.5.2. Programmer’s Model]()
		- [4.5.3. List of Registers]()
	- [4.6. Timer]()
		- [4.6.1. Overview]()
		- [4.6.2. Counter]()
		- [4.6.3. Alarms]()
- [Table of contents]()
		- [4.6.4. Programmer’s Model]()
		- [4.6.5. List of Registers]()
	- [4.7. Watchdog]()
		- [4.7.1. Overview]()
		- [4.7.2. Tick generation]()
		- [4.7.3. Watchdog Counter]()
		- [4.7.4. Scratch Registers]()
		- [4.7.5. Programmer’s Model]()
		- [4.7.6. List of Registers]()
	- [4.8. RTC]()
		- [4.8.1. Storage Format]()
		- [4.8.2. Leap year]()
		- [4.8.3. Interrupts]()
		- [4.8.4. Reference clock]()
		- [4.8.5. Programmer’s Model]()
		- [4.8.6. List of Registers]()
	- [4.9. ADC and Temperature Sensor]()
		- [4.9.1. ADC controller]()
		- [4.9.2. SAR ADC]()
		- [4.9.3. ADC ENOB]()
		- [4.9.4. INL and DNL]()
		- [4.9.5. Temperature Sensor]()
		- [4.9.6. List of Registers]()
	- [4.10. SSI]()
		- [4.10.1. Overview]()
		- [4.10.2. Features]()
		- [4.10.3. IP Modifications]()
		- [4.10.4. Clock Ratios]()
		- [4.10.5. Transmit and Receive FIFO Buffers]()
		- [4.10.6. 32-Bit Frame Size Support]()
		- [4.10.7. SSI Interrupts]()
		- [4.10.8. Transfer Modes]()
		- [4.10.9. Operation Modes]()
		- [4.10.10. Partner Connection Interfaces]()
		- [4.10.11. DMA Controller Interface]()
		- [4.10.12. APB Interface]()
		- [4.10.13. List of Registers]()
- [5. Electrical and Mechanical]()
	- [5.1. Package]()
		- [5.1.1. Thermal characteristics]()
		- [5.1.2. Recommended PCB Footprint]()
		- [5.1.3. Package markings]()
	- [5.2. Storage conditions]()
	- [5.3. Solder profile]()
	- [5.4. Compliance]()
	- [5.5. Pinout]()
		- [5.5.1. Pin Locations]()
		- [5.5.2. Pin Definitions]()
		- [5.5.3. Pin Specifications]()
	- [5.6. Power Supplies]()
	- [5.7. Power Consumption]()
		- [5.7.1. Peripheral power consumption]()
		- [5.7.2. Power consumption for typical user cases]()
- [Appendix A: Register Field Types]()
	- [Standard types]()
		- [RW]()
		- [RO]()
		- [WO]()
	- [Clear types]()
		- [SC]()
- [Table of contents]()
		- [WC]()
	- [FIFO types]()
		- [RF]()
		- [WF]()
		- [RWF]()
- [Appendix B: Errata]()
	- [Bootrom]()
		- [RP2040-E9]()
		- [RP2040-E14]()
	- [Clocks]()
		- [RP2040-E7]()
		- [RP2040-E10]()
	- [DMA]()
		- [RP2040-E12]()
		- [RP2040-E13]()
	- [GPIO / ADC]()
		- [RP2040-E6]()
		- [RP2040-E11]()
	- [USB]()
		- [RP2040-E2]()
		- [RP2040-E3]()
		- [RP2040-E4]()
		- [RP2040-E5]()
		- [RP2040-E15]()
	- [Watchdog]()
		- [RP2040-E1]()
	- [XIP Flash]()
		- [RP2040-E8]()
- [Appendix C: Availability]()
	- [Support]()
	- [Ordering code]()
- [Appendix D: Documentation release history]()

