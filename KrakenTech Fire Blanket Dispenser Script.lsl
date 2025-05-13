// =KT= KrakenTech Fire Blanket Dispenser Script v0.2.0
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

integer debugLevel = 0;                 // Current debug level, 0 turns off all debug msgs
string version = "v0.2.0";              // Current version number

string blanketName = "=KT= Fire Blanket";   // Name of fire blanket in inventory

integer strapFace = 2;                  // The face for the hanging straps

float   touchDistance = 5.0;            // How far away can someone succesfully get blanket
float   touchDelay = 30.0;              // How long to hide strraps and pause between blankets



// Global Variables

//      none for now



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


// Hide and show the straps!
hideStraps()
{
    llSetAlpha( 0.0, strapFace );       // Hide the straps
}
showStraps()
{
    llSetAlpha( 1.0, strapFace );       // Show the straps
}


// Return the location of the specified object
vector location( key id )
{
    list r = llGetObjectDetails( id, [OBJECT_POS] );
    
    // Return the position, if we have it.
    if ( r ) {
        return llList2Vector( r, 0 );
    } else {
        return ZERO_VECTOR;
    }
}


// Drop a blanket, with a REZ_PARAM_STRING pointing to the specified ID,
// so it knows how to attach to them
dropBlanket( key id )
{
    debug( 2, "dropBlanket(" + (string)id + ")" );
    
    if (id) {
        // Check if id is close enough!
        float distance = llVecDist( llGetPos(), location(id) );
        // debug( 2, "-> distance: " + (string)distance );
        
        // If too far away, let the user know and exit function without acting
        if ( distance > touchDistance ) {
            respond( id, "You are too far away, try to click within " + 
                (string)touchDistance + " meters" );
            return;
        }
        
        // Set up the rules to rez the blanket
        list rules = [ REZ_PARAM, TRUE ];
        rules += [ REZ_PARAM_STRING, (string)id ];
    
        // Rez the blanket
        llRezObjectWithParams( blanketName, rules );
        // The blanket then takes care of attaching itself
        
        // Hide the straps temporarily, pausing touchDelay seconds until ready
        hideStraps();
        llSleep( touchDelay );
        showStraps();
    } else {
        debug( 1, "dropBlanket() called with missing or invalid id." );
    }
}


default
{
    state_entry()
    {
        debug( 2, "state_entry()" );
        
        // Generate a description to identify the make and current version
        string desc = "=KT= Fire Blanket Dispenser " + version;
        if ( debugLevel )   desc += ", debug lvl " + (string)debugLevel;
        
        // Update the description
        list rules = [ PRIM_DESC, desc ];
        llSetLinkPrimitiveParamsFast( LINK_THIS, rules );        
    }

    touch_start(integer total_number)
    {
        debug( 2, "touch_start(" + (string)total_number + ")" );

        // Only process the first touch        
        key id = llDetectedKey( 0 );            // Who is responsible for this touch?
        if ( id ) {                             // Make sure we know who to give it to
            dropBlanket( id );                  // Drop the blanket
        }                                       // The blanket needs to attach itself
    }
}
