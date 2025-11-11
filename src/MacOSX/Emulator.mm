/*
 *	Emulator.mm - Class whose actions are attached to GUI widgets in a window,
 *				  used to control a single Basilisk II emulated Macintosh. 
 *
 *	$Id$
 *
 *  Basilisk II (C) 1997-2008 Christian Bauer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "Emulator.h"
#import "EmulatorView.h"

#import "sysdeps.h"			// Types used in Basilisk C++ code

#import "main_macosx.h"		// Prototypes for QuitEmuNoExit() and InitEmulator()
#import "misc_macosx.h"		// Some other prototypes
#import "video_macosx.h"	// Some window/view globals

#import "adb.h"
#import "main.h"
#import "prefs.h"
#import "timer.h"

#undef check				// memory.h defines a check macro,
							// which may clash with an OS X one on 10.1 or 10.2
#import "cpu_emulation.h"

#define DEBUG 0
#import "debug.h"

@implementation Emulator

// NSWindow method, which is invoked via delegation

- (BOOL) windowShouldClose: (id)sender
{
	if ( uaeCreated )
	{
		NSLog(@"windowShouldClose returning NO");
		return NO;	// Should initiate poweroff and return NSTerminateLater ?
	}

	NSLog(@"windowShouldClose returning YES");
	return YES;
}

// Default methods

- (Emulator *) init
{
	int frameSkip;

	self = [super init];

	running = NO;			// Save churn when application loads
//	running = YES;
	uaeCreated = NO;

	frameSkip = PrefsFindInt32("frameskip");
	if ( frameSkip )
		redrawDelay = frameSkip / 60.0;
	else
		redrawDelay = 0.0;

	// We do this so that we can work out if we are in full screen mode:
	parse_screen_prefs(PrefsFindString("screen"));

	return self;
}

- (void) awakeFromNib
{
	NSLog(@"DEBUG: awakeFromNib called");
	
	[self createThreads];
	
	the_win = win;					// Set global for access by Basilisk C++ code

	[win setDelegate: self];		// Enable windowShouldClose calling

	// Try to speed up everything
	[win useOptimizedDrawing: YES];			

	[win makeKeyAndOrderFront:self];

	if ( redrawDelay )
		[speed setFloatValue: 1.0 / redrawDelay];
	else
		[speed setFloatValue: 60.0];

	if ( runOrPause == nil )
		NSLog(@"%s - runOrPause button pointer is nil!", __PRETTY_FUNCTION__);

	[self runUpdate];
	
	// Add settings menu
	[self createSettingsMenu];
}

// Helpers which other classes use to access our private stuff

- (BOOL)			isRunning	{	return running;		}
- (BOOL)			uaeCreated	{	return uaeCreated;	}
- (EmulatorView *)	screen		{	return screen;		}
- (NSSlider *)		speed		{	return speed;		}
- (NSWindow *)		window		{	return win;			}


// Update some UI elements

- (void) runUpdate
{
	if ( running )
		[runOrPause setState: NSOnState];	// Running. Change button label to 'Pause'
	else
		[runOrPause setState: NSOffState];	// Paused.  Change button label to 'Run'
	
	[win setDocumentEdited: uaeCreated];	// Set the little dimple in the close button
}

// Check if ROM file exists, prompt user if not
- (void) checkROMFile
{
	const char *rom_path = PrefsFindString("rom");
	int rom_fd = -1;
	
	printf("DEBUG: checkROMFile called\n");
	if (rom_path) {
		printf("DEBUG: ROM path from prefs: %s\n", rom_path);
		rom_fd = open(rom_path, O_RDONLY);
		printf("DEBUG: ROM file open result: %d\n", rom_fd);
	} else {
		printf("DEBUG: No ROM path in prefs\n");
	}
	if (rom_fd < 0 && !rom_path) {
		printf("DEBUG: Trying default ROM file\n");
		rom_fd = open("ROM", O_RDONLY);
		printf("DEBUG: Default ROM open result: %d\n", rom_fd);
	}
	
	// If ROM file not found, prompt user to select one
	if (rom_fd < 0) {
		printf("DEBUG: Showing ROM file picker\n");
		NSOpenPanel *openPanel = [NSOpenPanel openPanel];
		[openPanel setCanChooseFiles:YES];
		[openPanel setCanChooseDirectories:NO];
		[openPanel setAllowsMultipleSelection:NO];
		[openPanel setTitle:@"Select ROM File"];
		[openPanel setMessage:@"Basilisk II needs a Macintosh ROM file to run.\nPlease select a ROM file (e.g., Quadra-650.ROM, Centris.ROM)"];
		[openPanel setPrompt:@"Select"];
		
		if ([openPanel runModal] == NSModalResponseOK) {
			NSURL *selectedURL = [[openPanel URLs] firstObject];
			NSString *path = [selectedURL path];
			rom_path = [path UTF8String];
			printf("DEBUG: User selected ROM: %s\n", rom_path);
			PrefsReplaceString("rom", rom_path);
			SavePrefs();
			rom_fd = open(rom_path, O_RDONLY);
			printf("DEBUG: Selected ROM open result: %d\n", rom_fd);
		}
		
		if (rom_fd < 0) {
			printf("DEBUG: No ROM selected, exiting\n");
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:@"No ROM File Selected"];
			[alert setInformativeText:@"Basilisk II cannot start without a ROM file. Please select a valid Macintosh ROM file."];
			[alert addButtonWithTitle:@"Exit"];
			[alert runModal];
			[alert release];
			exit(1);
		}
		close(rom_fd);
	} else {
		printf("DEBUG: ROM file found, closing fd\n");
		close(rom_fd);
	}
	
	// Verify ROM is still in prefs
	const char *final_rom = PrefsFindString("rom");
	printf("DEBUG: Final ROM in prefs: %s\n", final_rom ? final_rom : "NULL");
}

// Create basic settings menu
- (void) createSettingsMenu
{
	// Get main menu
	NSMenu *mainMenu = [NSApp mainMenu];
	
	// Create Settings menu
	NSMenuItem *settingsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Settings" action:nil keyEquivalent:@""];
	NSMenu *settingsMenu = [[NSMenu alloc] initWithTitle:@"Settings"];
	[settingsMenuItem setSubmenu:settingsMenu];
	
	// Add menu items
	NSMenuItem *romItem = [[NSMenuItem alloc] initWithTitle:@"Select ROM File..." action:@selector(selectROMFile:) keyEquivalent:@""];
	[romItem setTarget:self];
	[settingsMenu addItem:romItem];
	
	NSMenuItem *diskItem = [[NSMenuItem alloc] initWithTitle:@"Mount Disk Image..." action:@selector(selectDiskImage:) keyEquivalent:@""];
	[diskItem setTarget:self];
	[settingsMenu addItem:diskItem];
	
	NSMenuItem *memoryItem = [[NSMenuItem alloc] initWithTitle:@"Set Memory Size..." action:@selector(setMemorySize:) keyEquivalent:@""];
	[memoryItem setTarget:self];
	[settingsMenu addItem:memoryItem];
	
	NSMenuItem *screenItem = [[NSMenuItem alloc] initWithTitle:@"Set Screen Size..." action:@selector(setScreenSize:) keyEquivalent:@""];
	[screenItem setTarget:self];
	[settingsMenu addItem:screenItem];
	
	NSMenuItem *networkItem = [[NSMenuItem alloc] initWithTitle:@"Configure Network..." action:@selector(configureNetwork:) keyEquivalent:@""];
	[networkItem setTarget:self];
	[settingsMenu addItem:networkItem];
	
	// Add separator
	[settingsMenu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *savePrefsItem = [[NSMenuItem alloc] initWithTitle:@"Save Preferences" action:@selector(savePreferences:) keyEquivalent:@""];
	[savePrefsItem setTarget:self];
	[settingsMenu addItem:savePrefsItem];
	
	// Insert Settings menu before Help menu
	NSInteger helpIndex = [mainMenu indexOfItemWithTitle:@"Help"];
	if (helpIndex >= 0) {
		[mainMenu insertItem:settingsMenuItem atIndex:helpIndex];
	} else {
		[mainMenu addItem:settingsMenuItem];
	}
	
	[romItem release];
	[diskItem release];
	[memoryItem release];
	[screenItem release];
	[networkItem release];
	[savePrefsItem release];
	[settingsMenuItem release];
	[settingsMenu release];
}


// Methods invoked by buttons & menu items

- (IBAction) selectROMFile: (id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setTitle:@"Select ROM File"];
	[openPanel setMessage:@"Select a Macintosh ROM file (e.g., Quadra-650.ROM, Centris.ROM)"];
	[openPanel setPrompt:@"Select"];
	
	[openPanel beginSheetModalForWindow:win completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			NSURL *selectedURL = [[openPanel URLs] firstObject];
			NSString *path = [selectedURL path];
			const char *rom_path = [path UTF8String];
			PrefsReplaceString("rom", rom_path);
			SavePrefs();
			
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:@"ROM File Selected"];
			[alert setInformativeText:@"ROM file has been saved. Please restart Basilisk II to use the new ROM."];
			[alert addButtonWithTitle:@"OK"];
			[alert runModal];
			[alert release];
		}
	}];
}

- (IBAction) selectDiskImage: (id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setTitle:@"Select Disk Image"];
	[openPanel setMessage:@"Select a disk image file to mount (e.g., .hdf, .dsk, .iso)"];
	[openPanel setPrompt:@"Mount"];
	
	[openPanel beginSheetModalForWindow:win completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			NSURL *selectedURL = [[openPanel URLs] firstObject];
			NSString *path = [selectedURL path];
			const char *disk_path = [path UTF8String];
			
			// Add to disk preferences
			const char *existing_disks = PrefsFindString("disk");
			if (existing_disks) {
				// For now, just replace the first disk
				PrefsReplaceString("disk", disk_path);
			} else {
				PrefsAddString("disk", disk_path);
			}
			SavePrefs();
			
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:@"Disk Image Mounted"];
			[alert setInformativeText:@"Disk image has been added to preferences. Restart Basilisk II to mount the new disk."];
			[alert addButtonWithTitle:@"OK"];
			[alert runModal];
			[alert release];
		}
	}];
}

- (IBAction) setMemorySize: (id)sender
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:@"Set Memory Size"];
	[alert setInformativeText:@"Enter memory size in MB (recommended: 8-64)"];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	
	NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
	[input setStringValue:[NSString stringWithFormat:@"%d", PrefsFindInt32("ramsize") / (1024*1024)]];
	[alert setAccessoryView:input];
	
	[alert beginSheetModalForWindow:win completionHandler:^(NSModalResponse result) {
		if (result == NSAlertFirstButtonReturn) {
			int memoryMB = [input intValue];
			if (memoryMB > 0 && memoryMB <= 1024) {
				PrefsReplaceInt32("ramsize", memoryMB * 1024 * 1024);
				SavePrefs();
				
				NSAlert *confirm = [[NSAlert alloc] init];
				[confirm setMessageText:@"Memory Size Updated"];
				[confirm setInformativeText:[NSString stringWithFormat:@"Memory size set to %d MB. Restart Basilisk II to apply changes.", memoryMB]];
				[confirm addButtonWithTitle:@"OK"];
				[confirm runModal];
				[confirm release];
			}
		}
		[input release];
		[alert release];
	}];
}

- (IBAction) setScreenSize: (id)sender
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:@"Set Screen Size"];
	[alert setInformativeText:@"Select screen dimensions:"];
	[alert addButtonWithTitle:@"512x384"];
	[alert addButtonWithTitle:@"640x480"];
	[alert addButtonWithTitle:@"800x600"];
	[alert addButtonWithTitle:@"1024x768"];
	[alert addButtonWithTitle:@"Cancel"];
	
	[alert beginSheetModalForWindow:win completionHandler:^(NSModalResponse result) {
		if (result <= NSAlertThirdButtonReturn) {
			const char *width_height[] = {"512 384", "640 480", "800 600", "1024 768"};
			const char *selected = width_height[result - NSAlertFirstButtonReturn];
			PrefsReplaceString("screen", selected);
			SavePrefs();
			
			NSAlert *confirm = [[NSAlert alloc] init];
			[confirm setMessageText:@"Screen Size Updated"];
			[confirm setInformativeText:[NSString stringWithFormat:@"Screen size set to %s. Restart Basilisk II to apply changes.", selected]];
			[confirm addButtonWithTitle:@"OK"];
			[confirm runModal];
			[confirm release];
		}
		[alert release];
	}];
}

- (IBAction) configureNetwork: (id)sender
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:@"Configure Network"];
	[alert setInformativeText:@"Network configuration requires manual editing of preferences file for advanced options. Basic networking is enabled by default."];
	[alert addButtonWithTitle:@"OK"];
	[alert runModal];
	[alert release];
}

- (IBAction) savePreferences: (id)sender
{
	SavePrefs();
	
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:@"Preferences Saved"];
	[alert setInformativeText:@"Current settings have been saved to .basilisk_ii_prefs file."];
	[alert addButtonWithTitle:@"OK"];
	[alert runModal];
	[alert release];
}

- (IBAction) Benchmark:	(id)sender;
{
	BOOL	wasRunning = running;

	if ( running )
		[self Suspend: self];
	[screen benchmark];
	if ( wasRunning )
		[self Resume: self];
}

#ifdef NIGEL
- (IBAction) EjectCD: (id)sender;
{
	NSString	*path;
	const char	*cdrom = PrefsFindString("cdrom");

	if ( cdrom )
	{
	#include <sys/param.h>
	#define KERNEL
	#include <sys/mount.h>

		struct statfs buf;
		if ( fsstat(path, &buf) < 0 )
			return;

		path = [NSString stringWithCString: cdrom];

		[[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath: path];
//		[path release];
	}
}
#endif

- (IBAction) Interrupt:	(id)sender;
{
	WarningSheet (@"Interrupt action not yet supported", win);
}

- (IBAction) PowerKey:	(id)sender;
{
	if ( uaeCreated )		// If Mac has started
	{
		ADBKeyDown(0x7f);	// Send power key, which is also
		ADBKeyUp(0x7f);		// called ADB_RESET or ADB_POWER
	}
	else
	{
		running = YES;						// Start emulator
		[self runUpdate];
		[self Resume: nil];
	}
}

- (IBAction) Restart: (id)sender
{
	if ( ! running )
	{
		running = YES;						// Start emulator
		[self runUpdate];
		[self Resume: nil];
	}

	if ( running )
#ifdef UAE_CPU_HAS_RESET
		reset680x0();
#else
	{
		uaeCreated = NO;
		[redraw suspend];
		NSLog (@"%s - uae_cpu reset not yet supported, will try to fake it",
				__PRETTY_FUNCTION__);

		[screen clear];
		[screen display];

		[emul terminate]; QuitEmuNoExit();


		// OK. We have killed & cleaned up. Now, start afresh:
	#include <sys.h>
		int	argc = 0;
		char **argv;

		PrefsInit(NULL, argc, argv);
		SysInit();

		emul = [NNThread new];
		[emul perform:@selector(emulThread) of:self];
		[emul start];

		if ( display_type != DISPLAY_SCREEN )
			[redraw resume];
	}
#endif
}

- (IBAction) Resume: (id)sender
{
	[RTC	resume];
	[emul	resume];
	if ( display_type != DISPLAY_SCREEN )
		[redraw	resume];
	[tick	resume];
	[xPRAM	resume];
}

- (IBAction) ScreenHideShow: (NSButton *)sender;
{
	WarningSheet(@"Nigel doesn't know how to shrink or grow this window",
				 @"Maybe you can grab the source code and have a go yourself?",
				 nil, win);
}

- (IBAction) Snapshot: (id) sender
{
	if ( screen == nil || uaeCreated == NO  )
		WarningSheet(@"The emulator has not yet started.",
					 @"There is no screen output to snapshot",
					 nil, win);
	else
	{
		NSData	*TIFFdata;

		[self Suspend: self];

		TIFFdata = [screen TIFFrep];
		if ( TIFFdata == nil )
			NSLog(@"%s - Unable to convert Basilisk screen to a TIFF representation",
					__PRETTY_FUNCTION__);
		else
		{
			NSSavePanel *sp = [NSSavePanel savePanel];

			[sp setRequiredFileType:@"tiff"];

			if ( [sp runModalForDirectory:NSHomeDirectory()
									 file:@"B2-screen-snapshot.tiff"] == NSOKButton )
				if ( ! [TIFFdata writeToFile:[sp filename] atomically:YES] )
					NSLog(@"%s - Could not write TIFF data to file @%",
							__PRETTY_FUNCTION__, [sp filename]);

		}
		if ( running )
			[self Resume: self];
	}
}

- (IBAction) SpeedChange: (NSSlider *)sender
{
	float frequency = [sender floatValue];
	
	[redraw suspend];

	if ( frequency == 0.0 )
		redrawDelay = 0.0;
	else
	{
		frequencyToTickDelay(frequency);

		redrawDelay = 1.0 / frequency;

		[redraw changeIntervalTo: (int)(redrawDelay * 1e6)
						   units: NNmicroSeconds];
		if ( running && display_type != DISPLAY_SCREEN )
			[redraw resume];
	}
}

- (IBAction) Suspend: (id)sender
{
	[RTC	suspend];
	[emul	suspend];
	[redraw	suspend];
	[tick	suspend];
	[xPRAM	suspend];
}

- (IBAction) ToggleState: (NSButton *)sender
{
	running = [sender state];		// State of the toggled NSButton
	if ( running )
		[self Resume: nil];
	else
		[self Suspend: nil];
}

- (IBAction) Terminate: (id)sender;
{
	[self exitThreads];
	[win performClose: self];
}

#include <xpram.h>

#define XPRAM_SIZE	256

uint8 lastXPRAM[XPRAM_SIZE];		// Copy of PRAM

- (IBAction) ZapPRAM: (id)sender;
{
	memset(XPRAM,     0, XPRAM_SIZE);
	memset(lastXPRAM, 0, XPRAM_SIZE);
	ZapPRAM();
}

//
// Threads, Timers and stuff to manage them:
//

- (void) createThreads
{
#ifdef USE_PTHREADS
	// Make UI threadsafe:
	[NSThread detachNewThreadSelector:(SEL)"" toTarget:nil withObject:nil];
	//emul   = [[NNThread	alloc] initWithAutoReleasePool];
#endif
	emul   = [NNThread	new];
	RTC    = [NNTimer	new];
	redraw = [[NNTimer	alloc] initWithAutoRelPool];
	tick   = [NNTimer	new];
	xPRAM  = [NNTimer	new];

	[emul  perform:@selector(emulThread)	of:self];
	[RTC    repeat:@selector(RTCinterrupt)	of:self
			 every:1
			 units:NNseconds];
	[redraw	repeat:@selector(redrawScreen)	of:self
			 every:(int)(1000*redrawDelay)
			 units:NNmilliSeconds];
	[tick   repeat:@selector(tickInterrupt)	of:self
			 every:16625
			 units:NNmicroSeconds];
	[xPRAM  repeat:@selector(xPRAMbackup)	of:self
			 every:60
			 units:NNseconds];

	if ( running )		// Start emulator, then threads in most economical order
	{
		[emul	start];
		[xPRAM	start];
		[RTC	start];
		if ( display_type != DISPLAY_SCREEN )
			[redraw	start];
		[tick	start];
	}
}

- (void) exitThreads
{
	running = NO;
	[emul	terminate];  [emul	 release]; emul   = nil;
	[tick	invalidate]; [tick	 release]; tick   = nil;
	[redraw	invalidate]; [redraw release]; redraw = nil;
	[RTC	invalidate]; [RTC	 release]; RTC    = nil;
	[xPRAM	invalidate]; [xPRAM	 release]; xPRAM  = nil;
}

- (void) emulThread
{
	NSAutoreleasePool	*pool = [NSAutoreleasePool new];

	if ( ! InitEmulator() )
	{
		[redraw suspend];		// Stop the barberpole

		ErrorSheet(@"Cannot start Emulator", @"", @"Quit", win);
	}
	else
	{
		memcpy(lastXPRAM, XPRAM, XPRAM_SIZE);

		uaeCreated = YES;		// Enable timers to access emulated Mac's memory

		while ( screen == nil )	// If we are still loading from Nib?
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow: 1.0]];

		[self   runUpdate];		// Set the window close gadget to dimpled

		Start680x0();			// Start 68k and jump to ROM boot routine

		puts ("Emulator exited normally");
	}

	[pool release];
	QuitEmulator();
}

- (void) RTCinterrupt
{
	if ( ! uaeCreated )
		return;

	WriteMacInt32 (0x20c, TimerDateTime() );	// Update MacOS time

	SetInterruptFlag(INTFLAG_1HZ);
	TriggerInterrupt();
}

- (void) redrawScreen
{
	if ( display_type == DISPLAY_SCREEN )
	{
		NSLog(@"We are in fullscreen mode - why was redrawScreen() called?");
		return;
	}
	[barberPole animate:self];			// wobble the pole
	[screen setNeedsDisplay: YES];		// redisplay next time through runLoop
	// Or, use a direct method. e.g.
	//	[screen display] or [screen cgDrawInto: ...];
}

#include <main.h>				// For #define INTFLAG_60HZ
#include <rom_patches.h>		// For ROMVersion
#include "macos_util_macosx.h"	// For HasMacStarted()

- (void) tickInterrupt
{
	if ( ROMVersion != ROM_VERSION_CLASSIC || HasMacStarted() )
	{
		SetInterruptFlag (INTFLAG_60HZ);
		TriggerInterrupt  ();
	}
}

- (void) xPRAMbackup
{
	if ( uaeCreated &&
		memcmp(lastXPRAM, XPRAM, XPRAM_SIZE) )	// if PRAM changed from copy
	{
		memcpy (lastXPRAM, XPRAM, XPRAM_SIZE);	// re-copy
		SaveXPRAM ();							// and save to disk
	}
}

@end
