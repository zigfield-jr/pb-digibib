-(NSData*)rawImage1
{
	FILE* imagehandle;
	NSData* myImageData = nil;
	NSArray* myimageLocatorArray;
	int error;

//	NSLog(@"rawImageAddress1: %010p",imageAddress1);
//	NSLog(@"rawImageSize1: %d",imageSize1);

	myimageLocatorArray = [imageBand imageLocatorArray];

	if (myimageLocatorArray != nil)
	{
		myImageData = [self imageDataFromFolder:@"Small"];
	}
	else
	{
		NSFileHandle* myNSFileHandle = [NSFileHandle fileHandleForReadingAtPath:imageFilename];
		imagehandle = fdopen([myNSFileHandle fileDescriptor],"r");

//		imagehandle = fopen([imageFilename cString],"r");
		if (imagehandle == 0) return nil;

		error = fseek(imagehandle,imageAddress1,SEEK_SET);
		if (error) return nil;

		if (imageAddress1 == 0) return nil;

		char* mem = malloc(imageSize1);
		int menge = fread(mem,1,imageSize1,imagehandle);
		if (menge != imageSize1) return nil;

		myImageData = [NSData dataWithBytesNoCopy:mem length:imageSize1 freeWhenDone:YES];

		fclose(imagehandle);

		[myNSFileHandle closeFile];
	}

	return myImageData;
}

-(NSData*)rawImage2
{
	FILE* imagehandle;
	NSData* myImageData = nil;
	NSArray* myimageLocatorArray;
	int error;

//	NSLog(@"rawImageAddress2: %010p",imageAddress2);
//	NSLog(@"rawImageSize2: %d",imageSize2);

	myimageLocatorArray = [imageBand imageLocatorArray];

	if (myimageLocatorArray != nil)
	{
		myImageData = [self imageDataFromFolder:@"Small"];
	}
	else
	{
		NSFileHandle* myNSFileHandle = [NSFileHandle fileHandleForReadingAtPath:imageFilename];
		imagehandle = fdopen([myNSFileHandle fileDescriptor],"r");

//		imagehandle = fopen([imageFilename cString],"r");
		if (imagehandle == 0) return nil;

		if (imageAddress2 == 0) return nil;

		error = fseek(imagehandle,imageAddress2,SEEK_SET);
		if (error) return nil;

		char* mem = malloc(imageSize2);
		int menge = fread(mem,1,imageSize2,imagehandle);
		if (menge != imageSize2) return nil;

		myImageData = [NSData dataWithBytesNoCopy:mem length:imageSize2 freeWhenDone:YES];

		fclose(imagehandle);

		[myNSFileHandle closeFile];
	}

	return myImageData;
}

-(NSData*)rawImage3
{
	FILE* imagehandle;
	NSData* myImageData = nil;
	NSArray* myimageLocatorArray;
	int error;

//	NSLog(@"rawImageAddress3: %010p",imageAddress3);
//	NSLog(@"rawImageSize3: %d",imageSize3);

	myimageLocatorArray = [imageBand imageLocatorArray];

	if (myimageLocatorArray != nil)
	{
		myImageData = [self imageDataFromFolder:@"Huge"];
	}
	else
	{
		NSFileHandle* myNSFileHandle = [NSFileHandle fileHandleForReadingAtPath:imageFilename];
		imagehandle = fdopen([myNSFileHandle fileDescriptor],"r");

//		imagehandle = fopen([imageFilename cString],"r");
		if (imagehandle == 0) return nil;

		if (imageAddress3 == 0) return nil;

		error = fseek(imagehandle,imageAddress3,SEEK_SET);
		if (error) return nil;

		char* mem = malloc(imageSize3);
		int menge = fread(mem,1,imageSize3,imagehandle);
		if (menge != imageSize3) return nil;

		myImageData = [NSData dataWithBytesNoCopy:mem length:imageSize3 freeWhenDone:YES];

		fclose(imagehandle);

		[myNSFileHandle closeFile];
	}

	return myImageData;
}

-(NSString*)getImagePfad:(NSString*)_foldername
{
	NSArray* myimageLocatorArray;
	myimageLocatorArray = [imageBand imageLocatorArray];
	int i;
	int imageNumber;
	
	NSCharacterSet* characterSet;

	characterSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];

//	NSLog(@"imagename: %@",imageName);

	if ([imageBand majorNumber] == -15) {   // Liebig
		imageNumber = [[imageName substringWithRange:NSMakeRange(1,4)] intValue];
	}
	else {
		imageNumber = [[imageName stringByTrimmingCharactersInSet:characterSet] intValue];
	}
//	NSLog(@"imageNumber       : %d",imageNumber);

	for (i = 0 ; i < [myimageLocatorArray count] ; i++)
	{
//		NSLog(@"imagelocator index: %d",[[myimageLocatorArray objectAtIndex:i] intValue]);

		if (imageNumber < [[myimageLocatorArray objectAtIndex:i+1] intValue])
		{
			break;
		}
	}

	NSString* meisterPfad = [imageBand masterPath];

	NSString* pfad = [NSString stringWithFormat:@"/Images/%@/%02d/%@.jpg",_foldername, i, imageName];

//	NSLog(@"Pfad: %@",pfad);

	NSString* newpfad = [Helper findFile:pfad startPath:meisterPfad];

	return newpfad;
}

-(NSData*)imageDataFromFolder:(NSString*)_foldername
{
	NSData* myImageData;

	NSString* newpfad = [self getImagePfad:_foldername];

	myImageData = [NSData dataWithContentsOfFile:newpfad];

	if (myImageData == nil)
		NSLog(@"Error beim ImageData direkt laden (%@)",imageName);

	return myImageData;
}
