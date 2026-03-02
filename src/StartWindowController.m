-(NSString*)searchForDigiBib
{
	NSEnumerator* enu;
	NSString* object;

	NSFileManager* nsmanager = [NSFileManager defaultManager];

	NSArray* mountpoints = [nsmanager directoryContentsAtPath:@"/Volumes/"];

	enu = [mountpoints objectEnumerator];

	while (object = [enu nextObject])
	{
		NSString* path;
		NSString* newstring;

		path = [NSString stringWithFormat:@"/Volumes/%@",object];

		NSLog(@"checking: %@",path);

		newstring = [Helper findFile:@"data/digibib.txt" startPath:path];
		if ([[newstring lowercaseString] hasSuffix:@"digibib.txt"])
		{
			if ([nsmanager isReadableFileAtPath:newstring] == YES)
			{
				NSLog(@"was gefunden: %@",newstring);
				return newstring;
			}
		}

		// oder ist eventuell nur text.dki (wegen Band 1)

		newstring = [Helper findFile:@"data/text.dki" startPath:path];
		if ([[newstring lowercaseString] hasSuffix:@"text.dki"])
		{
			if ([nsmanager isReadableFileAtPath:newstring] == YES)
			{
				NSLog(@"was gefunden (ist wohl Band 1): %@",newstring);
				return newstring;
			}
		}
	}

	NSLog(@"keine CD eingelegt!");

	return nil;
}

- (IBAction) selectBandFromCDAction:(id)_sender
{
	id blub;

	[startWindowProgressIndicator startAnimation:self];

	NSFileManager* filemanager = [NSFileManager defaultManager];
	const char* unixfilename = [filemanager fileSystemRepresentationWithPath:masterpath];

	NSLog(@"path: %s",unixfilename);

	blub = [controller loadBand:masterpath];
	[[NSUserDefaults standardUserDefaults] setObject:masterpath forKey:@"lastLoadedBand"];

	[startWindowProgressIndicator stopAnimation:self];
}
