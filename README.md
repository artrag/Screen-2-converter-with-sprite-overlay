# Screen-2-converter-with-sprite-overlay
Convert any image to screen 2 and try to fix color spill by placing 16x16 sprites on the error areas


 call as  scr2cnv('namefile') from matlab

 Any image format is supported, .bmp, .png and .jpg files 
 will be accepted. Images
 - larger than 256x192 will be cropped to that size
 - smaller than 256x192 will be padded by zeros
  
 Images not in the TMS9918 color palette will be 
 converted without dithering closest color available 

 the program returns the following .bin files with msx basic header

 testcol.bin	-> screen 2 colors
 testpat.bin	-> screen 2 patterns
 testspt.bin	-> definitions of 32 sprites 16x16
 testsat.bin	-> attributes of 32 sprites

 In msx basic use this code to see the result 

	10 color 15,0,0:screen 2,2
	20 bload"testcol.bin",s
	30 bload"testpat.bin",s
	40 bload"testspt.bin",s
	50 bload"testsat.bin",s
	100 a$=input$(1)


