-(long)textPageNumber
{
//	NSLog (@"LineInTree: %d -> Page in Text: %d",linkNumber,[band pageNumberFromTree:linkNumber]);

	if (linkNumber == 23232323) return 1;
	
	if (linkNumber>1)
		return [band pageNumberFromTree:linkNumber];
	else
		return 0;
}
