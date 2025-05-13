// =KT= KrakenTech Fire Blanket Script v0.2.0
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
// Make sure the containing object is No Modify, and Physical


// Global constants

integer debugLevel = 0;             // Current debug level, 0 turns off all debug msgs
string version = "v0.2.0";          // Current version number

string bulletName = "=KT= Bullet";  // Name of bullet in inventory

integer listenChannel = 911;        // The channel to listen on for commands

integer attachPoint = ATTACH_PELVIS;    // Where do we attach to?

integer WATER = 0;                  // Water Bullet mode
integer FOAM = 1;                   // Foam Bullet mode
integer POWDER = 2;                 // Powder Bullet mode

// Strings for referring to the modes in commands
list modeStrings = [ "water", "foam", "powder"];

list blanketFaces = [ 0, 1 ];       // The face of the banket to update
float blanketAlpha = 1.0;           // The alpha value of the tinted face

list blanketTints = [               // Tints for the blanket for each mode
    <1.0, 1.0, 1.0>,                // water - based on cheap Fiberglass blankets
    <0.55, 0.52, 0.41>,             // foam - based on Army blankets
    <1.0, 0.44, 0.22>               // powder - based on Li-Ion blankets
];

vector dropOffset = <0.0, 0.0, -0.1>;       // The offset position to drop the blanket
rotation dropRot = <0.0, 0.0, PI, 0.0>;     // The rotation to drop the blanket


// Global Variables

integer bulletMode = WATER;         // Current bullet mode, default water
float bulletStrength = 20.0;        // Current bullet strength, default 20.0

integer dropped = FALSE;            // Has the blanket been dropped?

integer attaching = FALSE;          // Are we trying to attach right now?
key avatar = NULL_KEY;              // Who are we attaching to?

integer detachOnDrop = FALSE;       // Whether or not we detach the held blanket on drop

integer listenHandle;               // Handle for the listen channel



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


// Produce a llRezObject parameter based on the specfied mode (WATER/FOAM/POWDER) and strength
integer calcParameter( integer mode, float strength )
{
    return (mode*1000)+(integer)strength;
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

// Hide and show the blanket!
hideBlanket()
{
    llSetAlpha( 0.0, ALL_SIDES );       // Hide
}
showBlanket()
{
    llSetAlpha( 1.0, ALL_SIDES );       // Show
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
    
    // Transform command, changes the type of blanket and maybe strength
    if ( cmdToken == "transform" ) {
        string cMode = llList2String( tokens, 1 );      // New mode
        string cStrength = llList2String( tokens, 2 );  // New strength if present
        cmdTransform( id, cMode, cStrength );   // Run the transform command handler
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


// Transform command, to change the mode (& strenth?) of the blanket when dropped
cmdTransform( key id, string cMode, string cStrength )
{
    // If there's no cMode, skip it
    if ( cMode == "" ) {
        debug( 1, "Transform called without parameters" );
        return;
    }
    
    // Find the new mode in the list of modes
    integer newMode = llListFindList( modeStrings, [cMode] );
    if ( newMode == -1 ) {
        debug( 1, "Transform called with invalid mode: '"+cMode+"'" );
        return;
    }
    
    float newStrength = (float)cStrength;       // Parse the strength token to a float
    // Normalize it to default bulletStrength if it's not a good value
    if ( (newStrength<=0.0) || (newStrength>999.99999) ) {
        debug( 2, "Transform called with invalid strength: '"+cStrength+"'" );
        newStrength = bulletStrength;
    }
    
    if ( debugLevel >= 2) {
        string m = llList2String( modeStrings, newMode );
        debug( 2, "Transform to: "+m+" bullet @"+(string)newStrength );
    }

    // Store the updated values
    bulletMode = newMode;
    bulletStrength = newStrength;
    
    // Update the color of the held blanket    
    updateBlanketFaces( newMode );
}



// States & Events

default
{
    state_entry()
    {
        debug( 2, "state_entry()" );
        
        // Generate a description to identify the make and current version
        string desc = "=KT= Fire Blanket " + version;
        if ( debugLevel )   desc += ", debug lvl " + (string)debugLevel;
        
        // Update the description
        list rules = [ PRIM_DESC, desc ];
        llSetLinkPrimitiveParamsFast( LINK_THIS, rules );
        
        listenHandle = llListen( listenChannel, "", NULL_KEY, "" ); // Listen for cmds
    }
    
    
    // When we rez, see if we need to attach
    on_rez( integer param )
    {
        if ( param ) {
            string s = llGetStartString();        // Grab the UUID from StartString
            avatar = (key)s;
            
            // If id is invalid, don't attach of course
            if ( avatar == NULL_KEY )  {
                debug( 1, "Invalid ID: '" + s + "'" );
                return;
            }
            
            attaching = TRUE;                   // Let other events know we're attaching
            hideBlanket();                      // Hide Blanket until ready
            llRequestPermissions( avatar, PERMISSION_ATTACH );  // Request to attach
        } else {
            // If we're attached manually
            if ( llGetAttached() ) {            
                // Make sure we have appropriate permissions to detach
                llRequestPermissions( llGetOwner(), PERMISSION_ATTACH );
            }
        }
    }
    
    
    // If we're in the process of attaching, attach!
    run_time_permissions( integer perm )
    {
        if ( attaching && (PERMISSION_ATTACH&perm) ) {
            debug( 2, "-> attaching" );
            llAttachToAvatarTemp( attachPoint );    // Attach as temporary
            showBlanket();                          // Ready!  Show blanket again
            attaching = FALSE;                      // Done actually attaching
            detachOnDrop = TRUE;                    // Temp blankets disappear on drop
            
            // Object has changed, request permissions again to ensure we can detach
            llRequestPermissions( avatar, PERMISSION_ATTACH );  // Request to attach
        }
    }


    // Handle when we hear something on the right channel
    listen( integer channel, string name, key id, string msg )
    {
        // Only listen to the owner
        if ( id != llGetOwner() )   return;
        
        // Quickly massage the string for easier parsing
        msg = llStringTrim( msg, STRING_TRIM );     // Remove leading and trailing spaces
        msg = llToLower( msg );                     // Force everything to lowercase
        
        // Parse the remaining command line, running the command
        parseCommandLine( id, msg );
    }


    // Drop the blanket when touched
    touch_start(integer total_number)
    {
        debug( 1, "Touched!" );
        
        // Don't do anything unless touched by the owner
        if ( llDetectedKey(0) != llGetOwner() ) {
            debug( 2, "Touched by non-owner" );
            return;
        }

        // Better figure where we are        
        vector posOffset = ZERO_VECTOR;     // Offset from AVATAR_CENTER when attached
        if ( llGetAttached() ) {
            posOffset = llGetLocalPos() * llGetRot();
            debug( 2, "local: " + (string)posOffset );
        }
        
        // Where and how to put the dropped blanket
        vector pos = llGetPos() + posOffset + dropOffset;
        rotation rot = llGetRot() * dropRot;
        
        // Calculate the parameter to pass
        integer param = calcParameter( bulletMode, bulletStrength);
        
        // Rez the blanket at the new position
        llRezObject( bulletName, pos, ZERO_VECTOR, rot, param );
        
        // Clean myself up.  I'm not still holding the blanket if I just dropped the blanket
        // Only clean up if attached, leave it be if a freestanding prim for development
        if ( llGetAttached() && detachOnDrop ) {
            debug( 1, "Held Fire Blanket cleanup" );
            llDetachFromAvatar();
        }
    }
}
