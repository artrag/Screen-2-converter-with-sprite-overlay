function scr2cnv(name)
%
% call as  scr2cnv('namefile') from matlab
%
% Any image format is supported, .bmp, .png and .jpg files 
% will be accepted. Images
% - larger than 256x192 will be cropped to that size
% - smaller than 256x192 will be padded by zeros
%  
% Images not in the TMS9918 color palette will be 
% converted without dithering closest color available 
%
% the program returns the following .bin files with msx basic header
%
% testcol.bin	-> screen 2 colors
% testpat.bin	-> screen 2 patterns
% testspt.bin	-> definitions of 32 sprites 16x16
% testsat.bin	-> attributes of 32 sprites
%
% In msx basic use this code to see the result 
%
%	10 color 15,0,0:screen 2,2
%	20 bload"testcol.bin",s
%	30 bload"testpat.bin",s
%	40 bload"testspt.bin",s
%	50 bload"testsat.bin",s
%	100 a$=input$(1)


	close all

	% generate 256 binary  vectors for any unit8 

	dec2BinVec = logical(zeros(256,8));

	for i=0:255
		for j=1:8
			dec2BinVec(i+1,j) = logical(bitand(i,(2^(8-j)))>0);
		end
	end

	% TMS9918 rgb palette

	tmsmap = [         
			0.0       0.0       0.0
			0.0       0.0       0.0
			0.1294    0.7843    0.2588
			0.3686    0.8627    0.4706
			0.3294    0.3333    0.9294
			0.4902    0.4627    0.9882
			0.8314    0.3216    0.3020
			0.2588    0.9216    0.9608
			0.9882    0.3333    0.3294
			1.0000    0.4745    0.4706
			0.7843    0.7059    0.3294
			0.9020    0.8039    0.5020
			0.1294    0.6902    0.2314
			0.7882    0.3569    0.7294
			0.8000    0.8000    0.8000
			1.0000    1.0000    1.0000];


		%test images
		
		%name = '.\test images\outrun.png';
		%name = '.\test images\f3f3941d7aaff1cb902549be622a4e2e.jpg';
		%name = '.\test images\Golden Axe en Sega Master System, tops de 8 bits 2.png';
		%name = '.\test images\1end1-2-3_pal.png';
		 
		%name = '.\test images\170937_org.png';
		
		
	[org,map] = imread(name);
	  

	% convert any input image to an uint8 indexed image in the TMS palette

	if isempty(map)
		org = rgb2ind(org,tmsmap,'nodither');
		map = tmsmap;
	else
		org = imapprox(org,map,tmsmap,'nodither');
		map = tmsmap;
	end

	% crop to 256x192 
	t = zeros(192,256);
	t(1:min(192,size(org,1)),1:min(256,size(org,2))) = org(1:min(192,size(org,1)),1:min(256,size(org,2)));
	org = uint8(t);

	% open output files for patterns and colors

	fid1 = fopen('testpat.bin','wb');
	fwrite(fid1,hex2dec(['FE';'00';'00';'FF';'17';'00';'00']),'uint8');

	fid2 = fopen('testcol.bin','wb');
	fwrite(fid2,hex2dec(['FE';'00';'20';'FF';'37';'00';'00']),'uint8');

	% actual conversion, line by line, in screen 2 caracters, without dithering

	rec = uint8(zeros(size(org)));  % reconstructed image in 256x192 pixels
	for y=0:8:191
		% show progress at terminal
		disp(y/184*100)
		for x=0:8:255
			t = org((y+1):(y+8),(x+1):(x+8));
			for i=1:8
				[p,c] = vdpconvert(t(i,:),map);     % convert a 8x1 line
				fwrite(fid1,p,'uint8');
				fwrite(fid2,c,'uint8');
				c = uint8([bitand(c,15) (bitand(c,240)/16)]);
				rec((y+i),(x+1):(x+8)) = c(dec2BinVec(p+1,:)+1);    
			end
		end
	end
		
	fclose(fid1);
	fclose(fid2);

	% here we have
	% org: original 256x192 uint8 indexed image
	% rec: screen 2 conversion as 256x192 uint8 indexed image

	% Sprite positioning

	% replace 0 by 1 to avoid black sprites set to cover 0 areas

	org(org==0) = 1;
	rec(rec==0) = 1;


	% compute the error image between screen 2 and original, 

	sparse_err = org.*uint8(org~=rec);
	% exetend to 272x208 with zeros to allow sprites under the borders
	sparse_err = [sparse_err; zeros(16,256)];
	sparse_err = [sparse_err, zeros(208,16)];

	% find the box xmin,xmax ymin,ymax that enclose the non zero area of the
	% error image. It is not required, but it will speed up the processing

	[~,i] = find(sum(sparse_err>1)>0);
	xmax = max(i)-1;
	xmin = min(i)-1;

	[~,i] = find(sum(sparse_err'>1)>0);
	ymax = max(i)-1;
	ymin = min(i)-1;

	% open SAT and SPT output files

	fid1 = fopen('testspt.bin','wb');
	fwrite(fid1,hex2dec(['FE';'00';'38';'FF';'3C';'00';'00']),'uint8');

	fid2 = fopen('testsat.bin','wb');
	fwrite(fid2,hex2dec(['FE';'00';'1B';'7F';'1B';'00';'00']),'uint8');


	% YS: counter of number of sprites per line: each line has a counter 
	% starting from 0, increased each time we place a sprite covering that 
	% line, decreased each time we remove a sprite covering that line

	ys = zeros(192+16,1);   % sprites per line counter

	for s=0:31      %  for each sprite plane
		% show progress at terminal
		disp(s/31*100)

		dmax = 0;   % current max
		ym = 192;   % corrent box position
		
		for y=ymin:ymax
			for x=xmin:xmax     % scan pixel by pixel the non dummy image 
				for c=1:15      % for each non zero color
					
					% extract a 16x16 area in the error imade at x,y
					t = sparse_err( (y+1):(y+16),(x+1):(x+16) );
					% reset the lines whose counter is >=4
					t(ys((y+1):(y+16))>=4,:) = 0;
					% count the number of remaining pixel of color c
					d = sum(sum(t == c));
					% if the counter is larger than the dmax, set the
					% current postion as temporary best position for
					% the current sprite
					if (d>dmax) 
						ys((ym+1):(ym+16)) = ys((ym+1):(ym+16)) - 1;
						ys(( y+1):( y+16)) = ys(( y+1):( y+16)) + 1;
						ym = y;
						xm = x;
						cm = c;
						dmax = d;
					end
				end
			end
		end      
		% here xm,ym,cm are the best position for placing the current sprite 
		% of color cm
		
		% extract the box in the best position with the best color
		t = sparse_err( (ym+1):(ym+16),(xm+1):(xm+16) ) == cm;
		% reset the lines whose counter is >=4
		t(ys((ym+1):(ym+16))>=4,:) = 0; 
		% not t is the actual shape of the sprite to set
		
		% remove from the error image the sprite to set for next iterations
		sparse_err((ym+1):(ym+16),(xm+1):(xm+16)) = sparse_err((ym+1):(ym+16),(xm+1):(xm+16)).*uint8(not(t)); 

		% save in the SPT the sshape of the sprite
		fwrite(fid1,[128 64 32 16 8 4 2 1]*t(:,1: 8)','uint8');
		fwrite(fid1,[128 64 32 16 8 4 2 1]*t(:,9:16)','uint8');
		
		% save in the SAT position and color of the sprite
		fwrite(fid2,[ym-1,xm,s*4,cm],'uint8');
	end
	fclose(fid1);
	fclose(fid2);

	% crop residual error
	sparse_err = sparse_err(1:192,1:256);

	% the sprites set are equal to the original error minus the residual error
	sprites = org.*uint8(org~=rec) - sparse_err;

	% compute the screen 2 image + sprites
	nrec = rec;
	% where sprites are present, set their colors in the new reconstruction
	nrec(sprites>0) = sprites(sprites>0);

	% show input
	figure(1);
	subplot(2,3,1)
	image(org);
	title('Input image');
	colormap(map);
	axis equal
	axis image

	% show screeen 2 only reconstruction
	subplot(2,3,3)
	image(rec);
	title('tiles only');
	colormap(map);
	axis equal
	axis image

	% show screen 2 errors the error pixels are brighter with colors of the
	% original
	subplot(2,3,2)
	image(ind2rgb(org,map).*(0.4+(org~=rec)));
	title('error on tiles');
	colormap(map);
	axis equal
	axis image

	% show sprites
	subplot(2,3,4)
	image(sprites);
	colormap(map);
	title('sprites')
	axis equal
	axis image

	% show errors after sprites the error pixels are brighter with colors of
	% the original
	subplot(2,3,5)
	image(ind2rgb(org,map).*(0.4 + (org~=nrec)));
	colormap(map);
	title('error after sprites')
	axis equal
	axis image

	%show screen 2 + sprites
	subplot(2,3,6)
	image(nrec);
	colormap(map);
	title('screen 2 + sprites')
	axis equal
	axis image

	fclose('all');

	%used for testing with emulator and dirasdsk
	!copy *.bin .\basic
return


function [p,c] = vdpconvert(t,map)

    t = t + 1;
    rgb = map(t,:);

    dmin = inf;
    cmin = [0,0];
    pmin = zeros(8,1);

    for c0 = 1:16
        c0rgb = map(c0,:);
        for c1 = c0+1:16
            c1rgb = map(c1,:);
            p = zeros(8,1);
            m = 0;
            for i=1:8
                c = rgb(i,:);
                e0 = norm(c-c0rgb);
                e1 = norm(c-c1rgb);
                if (e0>e1)
                    p(i) = 1;
                    m = m + e1;
                else
                    p(i) = 0;
                    m = m + e0;
                end
            end 
            if (m<dmin)
                cmin = [c1,c0];
                pmin = p;
                dmin = m;
            end 
        end
    end
    c = (cmin(1)-1)*16+(cmin(2)-1);
	p = [128 64 32 16 8 4 2 1] * pmin;      
return
