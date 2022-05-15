# TASM-email-parser
An email address parser from files written in TASM.

# Compilation
You need to use DOSBOX and TASM in order to be able to compile&run this program.
```
tasm arcanoid.asm /l/zi
tlink arcanoid.obj /tdc
.\arcanoid.com
```

# How to use
The program asks for the FILENAME of the file to be parsed. 
After launching, all email addresses from FILENAME will be in the output.txt file 

# Problems I faced and solve
-> When parsing large files (more than 50,000 bytes), you have to read the file in parts, since it is a COM program and only uses 16-bit registers. Hence the problem that email addresses could break when read.

-> I needed to count the number of email addresses found. If it was more than 2¹⁶, it caused additional problems because I can't even work with DOUBLE WORD. To do this, I created a procedure ```smart_inc```, which makes counts up to 1,000,000, in decimal notation.
