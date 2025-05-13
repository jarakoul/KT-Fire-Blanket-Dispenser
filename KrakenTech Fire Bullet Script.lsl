// =KT= KrakenTech Fire Bullet Script v0.2.0
// For KrakenTech Fire Blankets, dispensed by KrakenTech Fire Blanket Dispensers
// A fire blanket for putting out HD fires
//
// Inspired by the Sombre Fire Blanket
//      Differences:
//          Autodeletes after a set period of time (1hr?)
//          Can transform from a water bullet (default) to a foam bullet or powder bullet
//          Can adjust strength
//          Can listen for an autodelete command
//
// Operation:
//      Dispenser should attach this to you.
//      Transform to new mode and strength if desired & allowed
//      Click to drop
//      Once dropped, it takes the form of the specified bullet to attack fires
//      Listens to commands at any point
//
// Make sure the containing object is No Modify, and Physical, place it in a
//  =KT= Fire Blanket


// Global constants

integer debugLevel = 0;             // Current debug level, 0 turns off all debug msgs
string version = "v0.2.0";          // Current version number

integer listenChannel = 999;        // The channel to listen on for commands

float smokeRange = 10.0;            // The range of the smoke detector

integer WATER = 0;                  // Water Bullet mode
integer FOAM = 1;                   // Foam Bullet mode
integer POWDER = 2;                 // Powder Bullet mode

// Strings for referring to the modes in commands
list modeStrings = [ "water", "foam", "powder"];

// Strings for generating the object name, to properly interact with HD Fire
list bulletNames = [ "Water", "Foam", "Powder"];

list blanketFaces = [ 0, 1 ];       // The face of the banket to update
float blanketAlpha = 1.0;           // The alpha value of the tinted face

list blanketTints = [               // Tints for the blanket for each mode
    <1.0, 1.0, 1.0>,                // water - based on cheap Fiberglass blankets
    <0.55, 0.52, 0.41>,             // foam - based on Army blankets
    <1.0, 0.44, 0.22>               // powder - based on Li-Ion blankets
];

//float timerInterval = 20.0;         // Timer interval in seconds (testing version)
//integer checkingDelay = 59;         // Time to go into into "checking" mode (testing version)
//integer cleaningDelay = 119;        // Time to cleanup (testing version)
float timerInterval = 600.0;         // Timer interval in seconds
integer checkingDelay = 1799;        // Time to go into into "checking" mode
integer cleaningDelay = 3599;        // Time to cleanup


// Global Variables

integer bulletMode = WATER;         // Current bullet mode, default water
float bulletStrength = 20.0;        // Current bullet strength, default 20.0

integer active = FALSE;             // Whether or not this blanket is actively functioning
integer checking = FALSE;           // Whether or not this blanket is in "checking" mode

integer listenHandle;               // Handle for the listen channel

float   checkingTime;               // When to go into "checking" mode
float   cleaningTime;               // When to give up checking and clean myself up

key     smokeID = NULL_KEY;         // 


// Functions

// Output a debug message if and only if debugLevel is high enough
debug( integer level, string message )
{
    if ( debugLevel >= level )
    {
        llOwnerSay( "! " + message );
    }
}


// Respond to the caller
respond( key id, string message )
{
    llRegionSayTo( id, 0, message );
}


// Intialize the script when it's rezzed or reset
initialize( integer param )
{
    debug( 2, "initialize("+(string)param+")" );
    
    // Start listening for commands
    listenHandle = llListen( listenChannel, "", NULL_KEY, "" );
    
    // If we've been passed a parameter
    if ( param > 0 ) {
        parseParameter( param );            // Parse it into bulletMode and bulltStrength
        updateBlanketFaces( bulletMode );   // Change the color to match the mode
        updateBlanketName( bulletMode, bulletStrength);   // And the name
        active = TRUE;                      // And I'm now an active blanket
        
        llResetTime();                                  // Restart the script time clock
        checkingTime = llGetTime() + checkingDelay;     // Store when to start "checking"
        cleaningTime = llGetTime() + cleaningDelay;     // Store when to cleanup
        llSetTimerEvent( timerInterval );               // Start the timer going
    }    
}


// Clean up the any active blanket/bullets when it's time to go away
cleanup()
{
    debug( 2, "cleanup() - active: " + (string)active );
    
    if ( active )   llDie();    // Only remove myself if I'm active!
}


// Parse a llRezObject parameter into mode (WATER/FOAM/POWDER) and strength, store them
parseParameter( integer param )
{
    // Do nothing with missing or invalid parameter
    if ( param <= 0 )   return;

    // Calculate base values    
    integer newMode = param / 1000;
    integer newStrength = param % 1000;
    
    // Normalize newMode
    if ( (newMode<0) || (newMode>=llGetListLength(modeStrings)) )   newMode = bulletMode;
    
    // Normalize strength
    if ( (newStrength<=0) || (newStrength>10000) )  newStrength = (integer)bulletStrength;
    
    // Store new values
    bulletMode = newMode;
    bulletStrength = (float)newStrength;
}


// Update the blanket color on this face to this tint
updateBlanketColor( integer face, vector tint )
{
    // Set the new tint
    list rules = [ PRIM_COLOR, face, tint, blanketAlpha ];
    llSetLinkPrimitiveParamsFast( LINK_THIS, rules );
}


// Update the blanket colors on each face from global constants
updateBlanketFaces( integer mode )
{
    // Do nothing if out of bounds
    if ( (mode<0) || (mode>=llGetListLength(blanketTints)) ) return;
    
    // Find the new tint
    vector tint = llList2Vector( blanketTints, mode );
    
    integer i;
    // Update each face on the blanketFaces list
    for ( i=0; i<llGetListLength(blanketFaces); i++ ) {
        updateBlanketColor( llList2Integer(blanketFaces,i), tint );
    }
}


// Update the blanket name according to the specified mode and strength
string updateBlanketName( integer mode, float strength )
{
    // Do nothing if out of bounds
    if ( (mode<0) || (mode>=llGetListLength(blanketTints)) ) return "";
    if ( strength < 0.0 ) return "";

    // Construct the new object name
    string modeName = llList2String( bulletNames, mode );
    string objName = modeName + " Bullet @ " + (string)strength;
    
    // Change the name of the object itself to the new name
    list rules = [ PRIM_NAME, objName ];
    llSetLinkPrimitiveParamsFast( LINK_THIS, rules );
    
    // Return the new object name if we want it
    debug( 2, "New Name: " + objName );
    return objName;
}


// Send out a sensor to detect if smoke is within range
smokeDetector( float range )
{
    llSensor( "SMOKE", NULL_KEY, ACTIVE, range, PI );
}


// Parse the command line and run the appropriate command
parseCommandLine( key id, string cmdLine )
{
    debug( 2, "cmdLine: '"+cmdLine+"'" );
    
    // Parse the remaining string down to its component bits
    list tokens = llParseString2List( cmdLine, [" ","\t","\n"], [] );
    string cmdToken = llList2String( tokens, 0 );
        
    // *** Check for each command and call the appropriate command handler ***
        
    // Ping command, returns a simple acknowledgement in chat privately to the caller
    if ( cmdToken == "ping" ) {
        cmdPing( id );      // Run the ping command handler
        return;             // And we're done;
    }
    
    // Smoke command, detect if there's nearby smoke
    if ( cmdToken == "smoke" ) {
        string cRange = llList2String( tokens, 1 );     // Range to check, in meters
        cmdSmoke( id, cRange );                         // Run the smoke command handler
        return;             // And we're done;
    }    
    
    // Clean command, manually clean up this blanket/bullet
    if ( cmdToken == "clean" ) {
        cmdClean( id );     // Run the clean command handler
        return;             // And we're done;
    }
            
    // Let the caller know the attempted command is invalid
    respond( id, "ERROR! Command not found: "+cmdToken );    
}



// *****************************************************************
//
// Command Handler Functions
//
// *****************************************************************


// Ping command, reply to the caller with a simple acknlowedgement
cmdPing( key id )
{
    respond( id, "Ack" );
}


// Smoke command, check if smoke is nearby
cmdSmoke( key id, string cRange )
{
    float range = (float)cRange;    // Convert the range parameter, if present
    
    // Normalize the range parameter, to make sure we're using a useful value
    if ( range <= 0.0 ) {
        range = smokeRange;         // Use the default if we don't have a good range
    }
    
    // Save the ID of the avi issuing the command for the later reply
    smokeID = id;
    
    // And send out the sensor
    smokeDetector( range );
}


// Clean command, cleanup time, cleanup time, everybody help, it's cleanup time
cmdClean( key id )
{
    if ( active ) {
        respond( id, "Manual Cleanup" );
        cleanup();
    }
}



// States & Events

default
{
    state_entry()
    {
        debug( 2, "state_entry()" );
        
        // Generate a description to identify the make and current version
        string desc = "=KT= Bullet " + version;
        if ( debugLevel )   desc += ", debug lvl " + (string)debugLevel;
        
        // Update the description
        list rules = [ PRIM_DESC, desc ];
        llSetLinkPrimitiveParamsFast( LINK_THIS, rules );
        
        initialize( 0 );                // Initialize the blanket
    }
    
    // When we rez a new copy, eg. when dropping
    on_rez( integer param )
    {
        initialize( param );            // Initialize the blanket
    }
    

    // Handle when we hear something on the right channel
    listen( integer channel, string name, key id, string msg )
    {
        // Quickly massage the string for easier parsing
        msg = llStringTrim( msg, STRING_TRIM );     // Remove leading and trailing spaces
        msg = llToLower( msg );                     // Force everything to lowercase
        
        // Parse the remaining command line, running the command
        parseCommandLine( id, msg );
    }
    
    
    // One of these two events gets triggered each time the smoke detector gets used
    // sensor if there is smoke, no_sensor if there is no smoke
    no_sensor()                         // No Smoke
    {
        debug( 2, "No smoke found." );
        
        // If there was a command caller, respond directly to them
        if ( smokeID ) {
            respond( smokeID, "No smoke found." );
            smokeID = NULL_KEY;
        }
        
        // If we're in checking mode, and no smoke is found, then clean up
        if ( checking )     cleanup();
    }
    sensor( integer num_detected )      // Smoke found
    {
        string info = "Smoke found: "+(string)num_detected;
        debug( 2, info );
        
        // If there was a command caller, respond directly to them
        if ( smokeID ) {
            respond( smokeID, info );
            smokeID = NULL_KEY;
        }        
    }
    
    
    // Timer event, to check when it's time to cleanup
    timer()
    {
        // If we're not active the timer shouldn't even be running
        if ( !active ) {
            debug( 1, "Timer event on inactive =KT= Bullet" );
            llSetTimerEvent( 0.0 );     // Disable the timer
            return;                     // And we're done
        }
        
        float time = llGetTime();       // Store the current time in a variable for ease
        debug( 2, "timer(): "+(string)time );
        
        // Is it cleaning time? If so clean up
        if ( time > cleaningTime ) {
            cleanup();
            return;
        }
        
        // Is it checking time? If so, let's check the smoke detector
        if ( time > checkingTime ) {
            debug( 1, "Checking mode" );
            checking = TRUE;
            smokeDetector( smokeRange );
        }
    }
}
