/***************************************************************************
 * Script to test wireless communication with the RFM12B tranceiver module
 * with an Arduino or Nanode board.
 *
 * Transmitter - Sends an incrementing number and flashes the LED every second.
 * Puts the ATMega and RFM12B to sleep between sends in case it's running on
 * battery.
 *
 * Ian Chilton <ian@chilton.me.uk>
 * December 2011
 *
 * Updated to Arduino v1.0 using Jeelibs by César García <cesargarciasaez@gmail.com>
 * 
 * Requires the Jeelibs, that combine Ports and RF12 libraries, from Jeelabs in your libraries directory:
 * https://github.com/jcw/jeelib
 * 
 * For additional info: http://jeelabs.org/jeelib
 *
 * Information on the RF12 library - http://jeelabs.net/projects/11/wiki/RF12
 *
 ***************************************************************************/

#include <Jeelib.h>

// Use the watchdog to wake the processor from sleep:
ISR(WDT_vect) { Sleepy::watchdogEvent(); }

// Send a single unsigned long:
static unsigned long payload;

void setup()
{
  // Serial output at 9600 baud:
  Serial.begin(9600);
  
  // LED on Pin Digital 6:
  pinMode(6, OUTPUT);
  
  // Initialize RFM12B as an 868Mhz module and Node 2 + Group 1:
  rf12_initialize(2, RF12_868MHZ, 1); 
}


void loop()
{
  // LED OFF:
  digitalWrite(6, LOW);
  
  Serial.println("Going to sleep...");
  
  // Need to flush the serial before we put the ATMega to sleep, otherwise it
  // will get shutdown before it's finished sending:
  Serial.flush();
  delay(5);
    
  // Power down radio:
  rf12_sleep(RF12_SLEEP);
  
  // Sleep for 5s:
  Sleepy::loseSomeTime(1000);
  
  // Power back up radio:
  rf12_sleep(RF12_WAKEUP);
  
  // LED ON:
  digitalWrite(6, HIGH);
    
  Serial.println("Woke up...");
  Serial.flush();
  delay(5);
  
  // Wait until we can send:
  while(!rf12_canSend())
    rf12_recvDone();
  
  // Increment data:
  payload++;
  
  // Send:
  rf12_sendStart(1, &payload, sizeof payload);
  rf12_sendWait(2);
  
  Serial.print("Sent ");
  Serial.println(payload);
}
