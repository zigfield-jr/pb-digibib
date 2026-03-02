unsigned long MAGIC = 1647820;

+(BOOL)isMagic:(FILE *)_f
{
	unsigned long plxmagic;

	fseek(_f,0,SEEK_SET);
	if ( 4 != fread(&plxmagic,1,4,_f)) {
		NSLog(@"isMagic() : error reading magic marker");
		exit(1);
	}

	return (plxmagic == MAGIC);   // magic number
}
