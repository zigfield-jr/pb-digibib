-(NSMutableAttributedString *)parsePageWithFontSize:(float)_fontsize suche:(BOOL)_sucheaktiv
{
	unsigned char* data;
	BOOL page_end = NO;
	NSData* temp_data;

	NSFont *bold_font,*italic_font,*bolditalic_font,*my_font;

	NSString* temp_string = nil;
	NSString* word = nil;

	NSFont *font;

	NSMutableString* temp2_string = nil;

	NSMutableAttributedString* backString;
	NSMutableAttributedString* ast;

	NSAttributedString* imageString;
	NSMutableAttributedString* returnString;
	NSMutableAttributedString* spaceString;

	NSRange myRange;

	NSString* atURL;
	NSURL* tempURL;
	DBImageSet* tempImageSet = nil;

	NSString* atlink = nil;
	
	int bold,italic,fontname,color,superscript,subscript;
	int autolink = 0,link2 = 0;

	int oldtoken = -9999;
	
	float fontsize = _fontsize;
	//float fontsize = 18.0;
	float newfontsize = 0;
	int num_tokens = 0;
	int i = 0;
	int len = 0;
	int _len = 0;
	int x = 0;
	int value;
	int linkrangebegin = 0;
	int urllinkrangebegin = 0;
	int hyphen = 0;
	int hyphen2 = 0;
	int hyphenck = 0;
	int atFont = 0;
	int atFarbe = 0;
	int word_start_pos = -1;
	int atVorWord=0;

	int positionAfterLastReturn = 0;

	atURL = nil;

	BOOL unicode = NO;
//	BOOL wordhasminussuffix=NO;

	bold=italic=fontname=color=superscript=subscript=0;

	int underline = -1;
	int zentriert = -1;

	NSMutableArray* zentriertArray = [[NSMutableArray alloc] init];

	data = (unsigned char *)[pageBlock bytes];

	backString = [[NSMutableAttributedString alloc] init];
	//NSLog(@"Fontsize: %f sucheaktiv: %d",fontsize,_sucheaktiv);
	if (_sucheaktiv) { ///GS
		fontsize=10.0;
	}
	my_font = [NSFont fontWithName:fontName size:fontsize];
	if (!my_font) NSLog(@"No font found %s:%d",__FILE__,__LINE__);
	bold_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask];
	if (!bold_font) NSLog(@"No font found %s:%d",__FILE__,__LINE__);
	bolditalic_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask|NSItalicFontMask];
	if (!bolditalic_font) NSLog(@"No font found %s:%d",__FILE__,__LINE__);
	italic_font = [my_font_manager convertFont:my_font toHaveTrait:NSItalicFontMask];
	if (!italic_font) NSLog(@"No font found %s:%d",__FILE__,__LINE__);

	NSString* zeichen = [NSString stringWithFormat:@"%C",NSAttachmentCharacter];
	imageString = [[[NSAttributedString alloc] initWithString:zeichen] autorelease];

	returnString = [[[NSMutableAttributedString alloc] initWithString:@"\n"] autorelease];
	[returnString addAttribute:NSFontAttributeName value:my_font range:NSMakeRange(0,1)];
	spaceString = [[[NSMutableAttributedString alloc] initWithString:@" "] autorelease];
	[spaceString addAttribute:NSFontAttributeName value:my_font range:NSMakeRange(0,1)];

	[backString appendAttributedString: returnString];  // erstmal ne leerzeile am anfang!
	[newWordList removeAllObjects];

	while (!page_end)
	{
		len = 0;
		num_tokens++;

		if (num_tokens >= 20000)
		{
			NSLog(@"mehr als 20000 token, wir brechen ab!");
			break;
		}

//		NSLog(@"token %d",data[i]);

		switch (data[i++])
		{
			case 0:		//	atBlanks
			{
				int numberOfSpaces = data[i++];
//				NSLog (@"atBlanks: %d",numberOfSpaces);
				NSString* tmpstring = [alotOfSpaces substringToIndex:numberOfSpaces];
				NSMutableAttributedString* temp = [[NSMutableAttributedString alloc] initWithString:tmpstring];
				[temp addAttribute:NSFontAttributeName value:my_font range:NSMakeRange(0,numberOfSpaces)];
				[backString appendAttributedString:temp];
				[temp release];
				break;
			}
			case 1:		//	atWord
			{
				len = data[i++];
				_len = (len & ~(0x80));				// _len wortlaenge

				if (_len == 1 && atFont != 0)
				{
					temp2_string = [[NSMutableString alloc] init];

					if (atFont == 1)
					{
						switch (data[i])
						{
							case 38:
//								[temp2_string appendString:[NSString stringWithUTF8String:""]];
								[temp2_string appendString:[NSString stringWithUTF8String:"▤"]];
								break;
							case 51:
								[temp2_string appendString:[NSString stringWithUTF8String:""]];
								break;
							case 65:
								[temp2_string appendString:[NSString stringWithUTF8String:"✌"]];		// 0x270C
								break;
							case 70:
								[temp2_string appendString:[NSString stringWithUTF8String:"☞"]];	// 0x261E
								break;
							case 164:
								[temp2_string appendString:[NSString stringWithUTF8String:"☉"]];	// 0x2609
								break;
							case 182:
								[temp2_string appendString:[NSString stringWithUTF8String:"✰"]];	// 0x2730
								break;
							case 240:
								[temp2_string appendString:[NSString stringWithUTF8String:"➝"]];	// 0x279D
								break;

							default:
								[temp2_string appendString:[NSString stringWithFormat:@"-%d-",data[i]]];
								NSLog(@"Font: %d  Char: %d",atFont,data[i]);
						}
					}
					else if (atFont == 2) 
					{
						switch (data[i])
						{
							case 45:
								[temp2_string appendString:[NSString stringWithUTF8String:"­"]]; // Zeichen ist unsichtbar
								break;
							case 200:
								[temp2_string appendString:[NSString stringWithUTF8String:"∪"]];
								break;
								
							default:
								[temp2_string appendString:[NSString stringWithFormat:@"-%d-",data[i]]];
								NSLog(@"Font: %d  Char: %d",atFont,data[i]);
						}
					}
					else
					{
						[temp2_string appendString:[NSString stringWithFormat:@"-%d-",data[i]]];
						NSLog(@"Font: %d  Char: %d",atFont,data[i]);
					}
				}
				else
				{
					unicode = NO;
					for (x = i ; x < i+_len-1;x++)
					{
						if (data[x] < 0x20)   // Es ist mindestens dezimal 20 (das ist bewiesen!)
						{
							unicode = YES;
							break;
						}
					}

					if (unicode == YES)
					{
						temp2_string = [[NSMutableString alloc] init];

						for (x = i ; x < i+_len;x++)
						{
							if (data[x] < 0x20)
							{
								unichar unizeichen;
//								NSLog(@"unicode: %02x:%02x",data[x],data[x+1]);
								unizeichen = data[x+1] - (data[x] + 1);
								unizeichen += 256 * (data[x] - 1);

//								NSLog(@"unicode: %04X",unizeichen);

								if (unizeichen >= 0x0700 && unizeichen < 0x1100)
									unizeichen += 0x1700;

								else if (unizeichen >= 0x1100 && unizeichen < 0x1200)
									unizeichen += (0xe000 - 0x1100);

								if (unizeichen >= 0x1200 && unizeichen < 0x1e00)
									NSLog(@"unicode: %04X",unizeichen);
								temp_string = [[NSString alloc] initWithCharacters:&unizeichen length:1];
								x++;
							}
							else
							{
								temp_data = [NSData dataWithBytes:&data[x] length:1];
								temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
							}

							if ([temp_string length] > 0)
								[temp2_string appendString:temp_string];

							[temp_string release];
						}
					}	// end if unicode == yes
					else	// kein unicode enthalten
					{
						temp_data = [NSData dataWithBytes:&data[i] length:_len];
						temp2_string = [[NSMutableString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
					}
				}
				//NSLog(@"atWord: %@",temp2_string);

// ---------------------------------------------------------------------------------------------------
// temp_string2 enthaelt das wort
// Einfuegen des wortes in die WORDLIST
				int backStringLength = [backString length]; // die beiden werden am ende auch
				int tmp2length = [temp2_string length];		// genutzt!

				if (atVorWord) {
					atVorWord=NO;
				}
				else {
					[self generateWordList:&data[i] Length:_len Range:NSMakeRange(backStringLength,tmp2length) Hyphen:hyphen||hyphen2||hyphenck  Font:atFont];
				}
					word = nil;
					word_start_pos = -1;
					hyphen = hyphenck = hyphen2 = 0;
//				ENDE einfuegen in die WORDLIST
// -----------------------------------------------------------------------------------------------------

				if (len > 0x80)	//	heisst blank am ende
				{
					//NSLog (@"atWord with a blank!");
					len = len - 0x80;
					num_tokens++;
					[temp2_string appendString:@" "];
					tmp2length++;
				}
				else {
					//NSLog (@"atWord without a blank!");
				}

				if (tmp2length > 0)
				{
					ast = [[NSMutableAttributedString alloc] initWithString:temp2_string];

					NSRange stringRange = NSMakeRange(0,tmp2length);

					if (superscript)
					{
						[ast addAttribute:NSSuperscriptAttributeName value:[NSNumber numberWithInt:1] range:stringRange];
					}
					else if (subscript)
					{
						[ast addAttribute:NSSuperscriptAttributeName value:[NSNumber numberWithInt:-1] range:stringRange];
					}

					if (bold && italic) font = bolditalic_font;
					else if (bold) font = bold_font;
					else if (italic) font = italic_font;
					else font = my_font;
					//NSLog(@"Font setzen!");
					[ast addAttribute:NSFontAttributeName value:font range:stringRange];
					//NSLog(@"Font setzen fertig!");
					[backString appendAttributedString:ast];

					[ast release];
				}

				[temp2_string release];

				break;
			}

			case 2:		//	atHardCRNew,
				//NSLog (@"atHardCRNew");
				[backString appendAttributedString: returnString];
				positionAfterLastReturn = [backString length];
				break;

			case 3:		//	atEndOfPage,
				//NSLog (@"atEndOfPage");
				page_end = YES;
				break;

			case 4:		//	atKursivAn,
				italic = 1;
				//NSLog (@"atKursivAn");
				break;

			case 5:		//	atKursivAus,
				italic = 0;
				//NSLog (@"atKursivAus");
				break;

			case 6:		//	atFettAn:
				//NSLog (@"atFettAn");
				bold = 1;
				break;

			case 7:		//	atFettAUS:
				//NSLog (@"atFettAUS");
				bold = 0;
				break;

			case 8:		//	atU,
			{
				value = data[i];
				//NSLog (@"atU: %d",value);
				i+=1;
				if (_sucheaktiv == NO)
				{
					newfontsize = 100.0;

					switch (value)
					{
						case 0:
							newfontsize = 100.0;
							bold = 0;
							italic = 0;
							break;
						case 1:
							newfontsize = 134.0;
							break;
						case 2:
							newfontsize = 122.0;
							break;
						case 3:
							newfontsize = 110.0;
							break;
						case 4:
							newfontsize = 100.0;
							bold = 1;
							break;
						case 5:
							newfontsize = 100.0;
							break;
						case 6:
							newfontsize = 100.0;
							italic = 1;
							break;
						default:
							NSLog(@"atU %d is unknown",value);
							break;
					}
					
					my_font = [my_font_manager convertFont:my_font toSize:fontsize*(newfontsize/100.0)];
					if (!my_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);

					bold_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask];
					if (!bold_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);
					bolditalic_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask|NSItalicFontMask];
					if (!bolditalic_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);
					italic_font = [my_font_manager convertFont:my_font toHaveTrait:NSItalicFontMask];
					if (!italic_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);
					
				}
				break;
			}

			case 9:	//	atLy:
			{
				NSLog (@"atLy");
			}

			case 10:	//	atImage:
			{
				int mywidth = (data[i+1]*256) + ((data[i]));
				i+=2;
				i+=2;
				len = data[i++];

				if (_sucheaktiv == NO)
				{
					zentriert = [backString length];		// bilder sind immer zentriert!
					NSLog (@"bild len: %d",len);
					temp_data = [NSData dataWithBytes:&data[i] length:len];
					temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
					NSLog(@"atImage: %@ width=%d",temp_string,mywidth);
						
					NSDictionary* imageDict = [band imageDict];
					DBImageSet* imageSet = [imageDict valueForKey:[[temp_string stringByDeletingPathExtension] lowercaseString]];
					NSImage* image = [imageSet image2];

					NSSize size = [image size];

					int finalwidth = ([band actualpageviewwidth] * mywidth / 1000.0) * 0.85;		// ein wenig runterskalieren!

					int newwidth = finalwidth;

					if (newwidth > size.width)
					{
						image = [imageSet image3];
						size = [image size];
					}

					int oldsize = size.width;

					size.width = finalwidth;
					size.height *= (size.width / oldsize);

					[image setScalesWhenResized:YES];		// scalieren einschalten!
					[image setSize:size];

					NSTextAttachment* attachment = [[NSTextAttachment alloc] init];
					[(NSCell *)[attachment attachmentCell] setImage:image];

					[backString appendAttributedString: imageString];
					[backString addAttribute:NSAttachmentAttributeName value:attachment range:NSMakeRange([backString length]-1,1)];
					[attachment release];
					[temp_string release];

					myRange = NSMakeRange(zentriert,[backString length]-zentriert); // Zentriert ende!
					[zentriertArray addObject:[NSValue valueWithRange:myRange]];
					zentriert = -1;
				}
				else  // suche aktiv
				{
					[backString appendAttributedString: imageString];
				}
				break;
			}

			case 11:	//	atLink:
			{
				len = data[i++];
//				NSLog (@"len: %d",len);
				temp_data = [NSData dataWithBytes:&data[i] length:len];
				atlink = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
				//NSLog(@"atLink: %@",atlink);
				linkrangebegin = [backString length];
				[atlink autorelease];
				break;
			}

			case 12:	//	atELink:
			{
				//NSLog (@"atELink");

				myRange = NSMakeRange(linkrangebegin,[backString length]-linkrangebegin);

				if (link2)
				{
					//NSLog(@"link2: %d",link2);
					[backString addAttribute:NSLinkAttributeName value:[NSNumber numberWithInt:link2] range:myRange];
					[backString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:myRange];
				}
				else if (tempImageSet)
				{
					NSLog(@"imageName: %@",[tempImageSet imageName]);
					[backString addAttribute:NSLinkAttributeName value:tempImageSet range:myRange];
					[backString addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:myRange];
				}
				else if (autolink)
				{
					//NSLog(@"autolink: %d",autolink);
					[backString addAttribute:NSLinkAttributeName value:[NSNumber numberWithInt:autolink] range:myRange];
					[backString addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:myRange];
				}
				else if (atlink)
				{
					//NSLog(@"atlink: %@",atlink);
					NSString* tmpstring = [atlink stringByDeletingPathExtension];
					id tmpobject = [[band imageDict] objectForKey:tmpstring];

					if (tmpobject)
					{
						[backString addAttribute:NSLinkAttributeName value:tmpobject range:myRange];
						[backString addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:myRange];
					}
				}
				
				tempImageSet = nil;
				linkrangebegin = 0;
				link2 = 0;
				autolink = 0;
				atlink = nil;
				break;
			}

			case 13:	//	atFont:
			{
				atFont = data[i];
				//NSLog (@"atFont: %d",atFont);
				i++;
				break;
			}

			case 14:	//	atFileName,
			{
				len = data[i++];
				//NSLog (@"len: %d",len);
				//temp_data = [NSData dataWithBytes:&data[i] length:len];
				//temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
				//NSLog(@"atFileName: %@",temp_string);
				//[temp_string release];
				break;
			}

			case 15:	//	atKonkor,
			{
				konkordanznumber = (data[i+1]*256) + data[i];	
				//NSLog (@"atKonkor: %d",konkordanznumber);
				i+=2;
				break;
			}
			case 16:	//	atNodeNumber
			{
				if (nodenumber == 0)
					nodenumber = ((data[i+1]*256)+data[i]) + 1;
				//NSLog (@"atNodeNumber: %d",nodenumber);
				i+=2;
				break;
			}

			case 17:	//	atHochAn
			{
				//NSLog (@"atHochAn");
				if (_sucheaktiv == NO)
				{
					superscript = 1;
					subscript = 0;

					my_font = [my_font_manager convertFont:my_font toSize:fontsize*0.66];
					bold_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask];
					bolditalic_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask|NSItalicFontMask];
					italic_font = [my_font_manager convertFont:my_font toHaveTrait:NSItalicFontMask];
				}
				break;
			}

			case 18:	//	atHochAus
			{
				//NSLog (@"atHochAus");
				if (_sucheaktiv == NO)
				{
					superscript = 0;

					my_font = [my_font_manager convertFont:my_font toSize:fontsize];
					bold_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask];
					bolditalic_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask|NSItalicFontMask];
					italic_font = [my_font_manager convertFont:my_font toHaveTrait:NSItalicFontMask];
				}
				break;
			}

			case 19:	//	atSigel,
			{
				len = data[i++];
//				//NSLog (@"len: %d",len);
				if (len > 0)
				{
					temp_data = [NSData dataWithBytes:&data[i] length:len];
					if ([temp_data length] > 0)
					{
						[pageSigel release];
						pageSigel = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
					}
				}
				//NSLog(@"atSigel: %@",pageSigel);
				break;
			}

			case 20:	//	atHeader {wird nicht mehr generiert - wurde es jemals?}
				//NSLog (@"atHeader");
				break;

			case 21:	//	atHyphen
				//NSLog (@"atHyphen");
				hyphen = 1;
				break;

			case 22:	//	atGesperrtAn		ACHTUNG: das ist underline !!!
				underline = [backString length];
				//NSLog (@"atGesperrtAn");
				break;

			case 23:	//	atGesperrtAus		ACHTUNG: das ist underline aus !!!
			{
				if (underline >= 0)
				{
					myRange = NSMakeRange(underline,[backString length]-underline);
					[backString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:1] range:myRange];
					
					underline = -1;
				}
				//NSLog (@"atGesperrtAus");
				break;
			}

			case 24:	//	atGriechischAn
				//NSLog (@"atGriechischAn");
				break;

			case 25:	//	atGriechischAus
				//NSLog (@"atGriechischAus");
				break;

			case 27:	//	atOneBlank:
				//NSLog (@"atOneBlank");
				[backString appendAttributedString: spaceString];
				break;

			case 28:	//	atLinieAn,
				//NSLog (@"atLinieAn");
				break;

			case 29:	//	atLinieAus,
				//NSLog (@"atLinieAus");
				break;

			case 30:	//	atTD,
				//NSLog (@"atTD");
				break;

			case 31:	//	atNil,
				//NSLog (@"atNil");
				break;

			case 128:	//	atLink2, {ersetzt atLink}
			{
				link2 = (data[i+2]*256*256)+(data[i+1]*256)+data[i];
				//NSLog(@"atLink2 zur seite: %d",link2);
				i+=4;
				len = data[i++];

				if (_sucheaktiv == NO)
				{
					linkrangebegin = [backString length];

//					//NSLog (@"len: %d",len);

					if (link2 == 0)
					{
						temp_data = [NSData dataWithBytes:&data[i] length:len];
						temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
						//NSLog(@"atLink2: %@",temp_string);
						tempImageSet = [[band imageDict] objectForKey:[[temp_string stringByDeletingPathExtension] lowercaseString]];
						[temp_string release];
					}
				}
				break;
			}
			case 129:	//	atID
				i++;
				//NSLog(@"atID");
				break;

			case 130:	//	atEID
				i++;
				//NSLog(@"atEID");
				break;

			case 131:	//	atTiefAn
			{
				//NSLog (@"atTiefAn");
				if (_sucheaktiv == NO)
				{
					subscript = 1;
					superscript = 0;
					
					my_font = [NSFont fontWithName:fontName size:fontsize*0.66];
					if (!my_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);	
					bold_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask];
					if (!bold_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);	
					bolditalic_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask|NSItalicFontMask];
					if (!bolditalic_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);	
					italic_font = [my_font_manager convertFont:my_font toHaveTrait:NSItalicFontMask];
					if (!italic_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);	
				}
				break;
			}
			case 132:	//	atTiefAus
			{
				//NSLog (@"atTiefAus");
				if (_sucheaktiv == NO)
				{
					subscript = 0;
					
					my_font = [NSFont fontWithName:fontName size:fontsize];
					if (!my_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);	
					bold_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask];
					if (!bold_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);	
					bolditalic_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask|NSItalicFontMask];
					if (!bolditalic_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);	
					italic_font = [my_font_manager convertFont:my_font toHaveTrait:NSItalicFontMask];
					if (!italic_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);	
				}
				break;
			}

			case 133:	//	atFarbe
			{
				atFarbe = data[i];
				i++;

				if (atFarbe)
				{
					//NSLog(@"atFarbe: %d",atFarbe);
				}
				break;
			}

			case 134:	//	atBildFliess
			{
			//	int mywidth = (data[i+1]*256) + data[i];
				i+=2;
			//	int myheight = (data[i+1]*256) + data[i];
				i+=2;
				len = data[i++];

				if (_sucheaktiv == NO)
				{

//					NSLog (@"len: %d",len);
					temp_data = [NSData dataWithBytes:&data[i] length:len];
					temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
					NSLog(@"atBildFliess: %@",temp_string);

					NSDictionary* imageDict = [band imageDict];
					DBImageSet* imageSet = [imageDict valueForKey:[[temp_string stringByDeletingPathExtension] lowercaseString]];
					NSImage* image = [imageSet image2];
					NSSize imagesize = [image size];

					float finalheight = [my_font defaultLineHeightForFont] + [my_font descender];
					int finalwidth = imagesize.width * finalheight / imagesize.height;

					imagesize.height = finalheight;
					imagesize.width = finalwidth;

					[image setScalesWhenResized:YES];		// scalieren einschalten!
					[image setSize:imagesize];

					NSTextAttachment* attachment = [[NSTextAttachment alloc] init];
					[(NSCell *)[attachment attachmentCell] setImage:image];

					[backString appendAttributedString: imageString];
					[backString addAttribute:NSAttachmentAttributeName value:attachment range:NSMakeRange([backString length]-1,1)];
					[attachment release];
					[temp_string release];
				}
				else  // sind im suchmodus
				{
					[backString appendAttributedString: imageString];					
				}
				break;
			}

			case 135:	//	atSuchWord
			{
				len = data[i++];
				temp_data = [NSData dataWithBytes:&data[i] length:len];
				temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
				//NSLog(@"atSuchWord %@",temp_string);
				[self addToWordList:temp_string Range:NSMakeRange(0,0) AllowSplit:NO];
				[temp_string autorelease];
				break;
			}

			case 136:	//	atSG
			{
				//NSLog (@"atSG: %d",data[i]);
				newfontsize = fontsize * (data[i] / 100.0);
				i++;

				if (_sucheaktiv == NO)
				{
					my_font = [NSFont fontWithName:fontName size:newfontsize];
					if (!my_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);
					bold_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask];
					if (!bold_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);
					bolditalic_font = [my_font_manager convertFont:my_font toHaveTrait:NSBoldFontMask|NSItalicFontMask];
					if (!bolditalic_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);
					italic_font = [my_font_manager convertFont:my_font toHaveTrait:NSItalicFontMask];
					if (!italic_font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);
				}
				break;
			}

			case 137:	//	atCopyRight
				//NSLog(@"atCopyRight: %d",data[i]);
				i++;
				break;

			case 138:	//	atAutoLink
				linkrangebegin = [backString length];
				autolink = (data[i+2]*256*256)+(data[i+1]*256)+data[i];
				//NSLog (@"atAutoLink zu seite: %d",autolink);
				i+=4;
				break;

			case 139:	//	atSoftCRNew,
				//NSLog (@"atSoftCRNew");
				[backString appendAttributedString: returnString];
				positionAfterLastReturn = [backString length];
				break;

			case 140:	//	atHyphen2,
				//NSLog (@"atHyphen2");
				hyphen2 = 1;
				break;

			case 141:	//	atNewGesperrt,
				//NSLog (@"atNewGesperrt");
				break;

			case 142:	//	atENewGesperrt,
				//NSLog (@"atENewGesperrt");
				break;

			case 143:	//	atHZA
			{
				//NSLog (@"atHZA");

				if (_sucheaktiv == NO)
				{
					font = [my_font_manager convertFont:my_font toSize:fontSize/2];
					if (!font) NSLog(@"font not found %s:%d",__FILE__,__LINE__);
					
					int start = [backString length];
					
					[backString appendAttributedString: returnString];
					[backString appendAttributedString: spaceString];
					[backString addAttribute:NSFontAttributeName value:font range:NSMakeRange(start,2)];
				}
				break;
			}
			case 144:	//	atLI
				//NSLog (@"atLI");
				break;

			case 145:	//	atELI
				//NSLog (@"atELI");
				break;

			case 146:	//	atUL
				//NSLog (@"atUL");
				break;

			case 147:	//	atEUL
				//NSLog (@"atEUL");
				break;

			case 148:	//	atSetX offset linker rand pixel
			{
				int temp = (data[i+1]*256) + data[i];
				i+=2;
				
				if (temp)
				{
					//NSLog(@"atSetX: %d",temp);

					float xvalue = temp * [band actualpageviewwidth] / 1000.0;
					float spaceweite = [spaceString size].width;
					int zeilenlaenge = [backString length] - positionAfterLastReturn;

					NSRange myRange = NSMakeRange(positionAfterLastReturn,zeilenlaenge);

					float abziehen = [[backString attributedSubstringFromRange:myRange] size].width;
					float fillspace = xvalue - abziehen;

					if (fillspace >= 1)
					{
						int numberOfSpaces = fillspace / spaceweite;

						//NSLog(@"actualpageviewwidth: %d",[band actualpageviewwidth]);
//						NSLog(@"xvalue: %0.1f",xvalue);
//						NSLog(@"postitionAfterLastReturn: %d",positionAfterLastReturn);
//						NSLog(@"backString laenge: %d",[backString length]);
//						NSLog(@"zeilenlaenge: %d",zeilenlaenge);
//						NSLog(@"spaceweite: %0.1f",spaceweite);
//						NSLog(@"zeilenlaenge in pixel: %0.1f",abziehen);
//						NSLog(@"numberofSpaces: %d",numberOfSpaces);

						NSString* tmpstring = [alotOfSpaces substringToIndex:numberOfSpaces];
						NSMutableAttributedString* temp2 = [[NSMutableAttributedString alloc] initWithString:tmpstring];
						[temp2 addAttribute:NSFontAttributeName value:my_font range:NSMakeRange(0,numberOfSpaces)];

						[backString appendAttributedString: temp2];
					}
				//NSLog (@"atSetX");
				}
				break;
			}
			case 149:	//	atSV
				i+=8;
				break;

			case 150:   // atSVStichwort
			{
				len = data[i++];
//				//NSLog (@"len: %d",len);
				temp_data = [NSData dataWithBytes:&data[i] length:len];
				temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
				//NSLog(@"atSVStichwort: %@",temp_string);
				[temp_string release];
				break;
			}
			case 151:   // atKeinSVFF
				break;

			case 152:	//	atZ		(Zentriert)
				//NSLog (@"atZentriert");
				zentriert = [backString length];
				break;

			case 153:	//	atZE	(Zentriert Ende)
			{
				//NSLog (@"atZentriertEnde");

				if (zentriert >= 0)
				{
					myRange = NSMakeRange(zentriert,[backString length]-zentriert);
					[zentriertArray addObject:[NSValue valueWithRange:myRange]];
					zentriert = -1;
				}
				break;
			}
			case 154:	//	atR
				//NSLog (@"atR");
				break;

			case 155:	//	atER
				//NSLog (@"atER");
				break;

			case 156:	//	atE, {wird nicht mehr verwendet!!!}
				//NSLog (@"atE");
				i+=2;
				break;

			case 157:	//	atEE,
				//NSLog (@"atEE");
				break;

			case 158:	//	atBiblioPageNr,
				//NSLog (@"atBiblioPageNr");
				i+=4;
				break;

			case 159:	//	atNotFirstLine,
				//NSLog (@"atNotFirstLine");
				break;

			case 160:	//	atThumbXXX,
				//NSLog (@"atThumbXXX");
				break;

				case 161:	//	atENew,
				//NSLog (@"atENew");
				i+=3;
				break;

			case 162:	//	atURL,
			{
				//NSLog (@"atURL");
				len = data[i++];

				[atURL release];
				atURL = nil;

				urllinkrangebegin = [backString length];

				if (len > 0)
				{
					temp_data = [NSData dataWithBytes:&data[i] length:len];
					if ([temp_data length] > 0)
						atURL = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
				}
				break;
			}
			case 163:	//	atEURL
			{
				//NSLog (@"atEURL");
				//NSLog(@"URL: %@",atURL);
				
				myRange = NSMakeRange(urllinkrangebegin,[backString length]-urllinkrangebegin);

				[backString addAttribute:NSLinkAttributeName value:atURL range:myRange];
				[backString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:myRange];

				linkrangebegin = 0;
				link2 = 0;
				autolink = 0;
				[atURL release];
				atURL = nil;
				
				break;
			}
			case 164:	//	atWortAnker,
				//NSLog(@"atWortAnker");		// Vlado fragen
				break;
				
			case 165:	//	atThumbWWW,
				//NSLog(@"atThumbWWW");
				break;
				
			case 166:	//	atS,
				//NSLog(@"atS");
				break;

			case 167:	//	atKeinBlocksatzAn
				//NSLog (@"atKeinBlocksatzAn");
				break;

			case 168:	//	atKeinBlocksatzAus
				//NSLog (@"atKeinBlocksatzAus");
				break;

			case 169:	//	atNextBlankIsFixed,
				//NSLog(@"atNextBlankIsFixed");
				break;

			case 170:	//	atRestWord
			{
				len = data[i++];
				if (len > 0x80) {	// heisst blank am ende
					len = len - 0x80;
//					num_tokens++;
//					NSLog(@"Achtung, numtokens wurde manuell erhoeht!");
				}
				temp_data = [NSData dataWithBytes:&data[i] length:len];
				temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
				//NSLog(@"atRestWord %@",temp_string);

                                [self generateWordList:&data[i] Length:len Range:NSMakeRange([backString length],len) Hyphen:hyphen||hyphen2||hyphenck  Font:atFont];

//				[self addToWordList:[word stringByAppendingString:temp_string] Range:r AllowSplit:YES];
				
				[temp_string release];
				break;
			}
			case 171:	//	atVorWord
				len = data[i++];
				atVorWord=YES;
                                hasVorWort=YES;
//				temp_data = [NSData dataWithBytes:&data[i] length:len];
//				temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
//				NSLog(@"atVorWord %@",temp_string);
//				[temp_string release];
				break;

			case 172:	//	atHyphenCK
				//NSLog (@"atHyphenCK");
				hyphenck = 1;
				break;

			case 173:	//	atHebrAn
				//NSLog (@"atHebrAn");
				break;

			case 174:	//	atHebrAus
				//NSLog (@"atHebrAus");
				break;

			case 175:	//	atNodeNumber2
				if (nodenumber == 0)
					nodenumber = ((data[i+2]*256*256)+(data[i+1]*256)+data[i]) + 1;
				//NSLog (@"atNodeNumber2: %d",nodenumber);
				i+=4;
				break;

			case 176:	//	atDurchAn
				//NSLog (@"atDurchAn");
				break;
				
			case 177:	//	atDurchAus
				//NSLog (@"atDurchAus");
				break;
				
			case 178:	//	atSetY
				i+=2;
				//NSLog (@"atSetY");
				break;

			case 179:	//	atCor
				//NSLog (@"atCor");
				break;

			case 180:	//	atECor
				//NSLog (@"atECor");
				break;
				
			default:	// keinen passenden Tag gefunden!
				NSLog(@"pagenumber: %d  num_tokens: %d  pos: %d  Unknown token: %d",textpagenumber,num_tokens,i,data[i-1]);
				NSLog(@"token before: %d",oldtoken);
				page_end = YES;
				break;
		}

		oldtoken = data[i-1];

		i += len;
		if (i >= pageBlocklength)
		{
			//NSLog(@"pageblock ende: %d",i);
			page_end = YES;
		}
	}

//  nur wenn keine suche dann einen echten string aufbauen
	
	if (_sucheaktiv == NO)
	{

//		mal schauen ob ein atZentriert offen ist.

		if (zentriert >= 0)
		{
			myRange = NSMakeRange(zentriert,[backString length]-zentriert);
			[zentriertArray addObject:[NSValue valueWithRange:myRange]];
			zentriert = -1;
		}

		//  linken rand ein wenig einruecken (lineindent)

		NSMutableParagraphStyle* myParagraphStyle;

		myParagraphStyle = [[NSMutableParagraphStyle alloc] init];

		[myParagraphStyle setHeadIndent:40.0];
		[myParagraphStyle setFirstLineHeadIndent:40.0];
		[myParagraphStyle setLineSpacing:linespacing];

		[backString addAttribute:NSParagraphStyleAttributeName value:myParagraphStyle range:NSMakeRange(0,[backString length])];
		[myParagraphStyle release];

		//		jetzt erst alle zentrierten stellen setzen!

		NSEnumerator* enu = [zentriertArray objectEnumerator];
		myParagraphStyle = [[NSMutableParagraphStyle alloc] init];
		[myParagraphStyle setAlignment:NSCenterTextAlignment];
		NSValue* rangevalue;

		while (rangevalue = [enu nextObject])
		{
			[backString addAttribute:NSParagraphStyleAttributeName value:myParagraphStyle range:[rangevalue rangeValue]];
		}
		[myParagraphStyle release];
		[zentriertArray release];

//		[self colorizeWords: backString Foreground:YES];
//		[self colorizeWords: backString Foreground:NO];

		[self highlightSearchPosition:searchPosition string:backString];

		if (showMarkierungen)
			[self highlightMarkierungen:[[self band] markierungenDS] string:backString];

		if (i != pageBlocklength)
			NSLog(@"i = %d size = %d",i,pageBlocklength);

		if (atomCount != num_tokens && atomCount != 0)
			NSLog(@"num_tokens = %d soll_tokens = %d",num_tokens,atomCount);
		
		return backString;
	}
	else
		return nil;
}

-(void)displayPageInView:(NSTextView*)_view
{
	NSMutableAttributedString* parsedString;
	NSTextStorage* textStorage;
	NSFont* my_font;

	static float oldfontSize;
	static float oldViewWidth=1000;
	static float oldViewHeight=1464;

	NSSize stringSize;

	NSRect pageviewbounds = [_view bounds];
//	NSLog (@"PAGEVIEW: weite: %.0f  hoehe: %.0f",pageviewbounds.size.width,pageviewbounds.size.height);

	float hoehe = (pageviewbounds.size.height);
	float weite = (pageviewbounds.size.width) - 40 - 8;

	//NSLog(@"PAGEVIEW (old)h: %0.f   w: %0.f   oldfontsize: %0.f",oldViewHeight,oldViewWidth,oldfontSize);

	if (abs(weite) != abs(oldViewWidth) || abs(hoehe) != abs(oldViewHeight))
	{
		fontSize = 5;

		[band setactualpageviewwidth:(int)pageviewbounds.size.width];

		NSMutableAttributedString* myAString = [[NSMutableAttributedString alloc] initWithString:vladoTestString];
		NSRange stringrange = NSMakeRange(0,[myAString length]);
		my_font = [NSFont fontWithName:fontName size:fontSize];
		if(!my_font) NSLog(@"font %@ not found fs:%f %s:%d",fontName,fontSize,__FILE__,__LINE__);

		if (hoeheistegal == YES) hoehe = 999999;

		do
		{
			//NSLog (@"CSTRING: viewhoehe: %0.f viewweite: %0.f weite: %.0f hoehe(*28): %.0f",hoehe,weite,stringSize.width,(stringSize.height)*27.0);

			fontSize++;
			linespacing = fontSize / 17.0;
			my_font = [my_font_manager convertFont:my_font toSize:fontSize];
			if(!my_font) NSLog(@"font %@ not found fs:%f %s:%d",fontName,fontSize,__FILE__,__LINE__);
			[myAString addAttribute:NSFontAttributeName value:my_font range:stringrange];
			stringSize = [myAString size];
		}
		while ((stringSize.width < weite) && (((stringSize.height+linespacing) * 28.0) < hoehe));

		[myAString release];

		//NSLog (@"CSTRING: viewhoehe: %0.f viewweite: %0.f weite: %.0f hoehe(*28): %.0f",hoehe,weite,stringSize.width,(stringSize.height)*27.0);

		fontSize--;
	}
	else
	{
		fontSize = oldfontSize;
		linespacing = (fontSize+1.0) / 17.0;
	}

	if (oldfontSize == fontSize && enforceRedisplay == NO)
	{
		//return;
	}

	oldfontSize = fontSize;
	oldViewWidth = weite;
	oldViewHeight = hoehe;

	parsedString = [self parsePageWithFontSize:fontSize suche:NO];

	enforceRedisplay = NO;

	textStorage = [_view textStorage];
	[textStorage setAttributedString:parsedString];
	[_view setNeedsDisplay:YES];

	//NSLog(@" DBPage : Frame: %0.f x %0.f Bounds : %0.f x %0.f",[_view frame].size.width,[_view frame].size.height,[_view bounds].size.width,[_view bounds].size.height);
	//NSLog(@"END displayPageInView()");
}
