# Screen-2-converter-with-sprite-overlay
Convert any image to screen 2 (msx 1) and try to fix color spill by placing 16x16 sprites on the error areas


 call as  scr2cnv('namefile') from matlab

 Any image format is supported, .bmp, .png and .jpg files 
 will be accepted. Images
 - larger than 256x192 will be cropped to that size
 - smaller than 256x192 will be padded by zeros
  
 Images not will be converted pixel by pixel without dithering to the closest color available in the TMS9918 palette

 The program returns the following .bin files with msx basic header

- testcol.bin	-> screen 2 colors
- testpat.bin	-> screen 2 patterns
- testspt.bin	-> definitions of 32 sprites 16x16
- testsat.bin	-> attributes of 32 sprites

If you want to use these files with Colecovision, TI99/4A or any another machine 
based on the TMS9918,  remove the first 7 bytes from the header to get raw data

 In msx basic use this code to see the result 

	10 color 15,0,0:screen 2,2
	20 bload"testcol.bin",s
	30 bload"testpat.bin",s
	40 bload"testspt.bin",s
	50 bload"testsat.bin",s
	100 a$=input$(1)


