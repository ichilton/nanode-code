/***************************************************************************
 * Script to test wireless communication with the RFM12B tranceiver module
 * with an Arduino or Nanode board.
 *
 * Receiver - receives packets sent by the transmitter and send them out to
 * the serial console.
 *
 * Ian Chilton <ian@chilton.me.uk>
 * December 2011
 *
 * Requires Arduino version 0022. v1.0 was just released a few days ago so
 * i'll need to update this to work with 1.0.
 *
 * Requires the Ports and RF12 libraries from Jeelabs in your libraries directory:
 *
 * http://jeelabs.org/pub/snapshots/Ports.zip
 * http://jeelabs.org/pub/snapshots/RF12.zip
 *
 * Information on the RF12 library - http://jeelabs.net/projects/11/wiki/RF12
 *
 ***************************************************************************/

#include <Ports.h>
#include <RF12.h>

static unsigned long payload;

void setup()
{
  // Serial on 9600 baud:
  Serial.begin(9600);
  
  // LED on Pin Digital 6:
  pinMode(6, OUTPUT);

  // Initialize RFM12B as an 868Mhz module and Node 1 + Group 1:
  rf12_initialize(1, RF12_868MHZ, 1); 
}


void loop()
{
  // If a packet is received, if it's valid and if it's of the same size as our payload:
  if (rf12_recvDone() && rf12_crc == 0 && rf12_len == sizeof payload)
  {
    // Copy the received data into payload:
    memcpy(&payload, (byte*) rf12_data, sizeof(payload));

    // Flash LED:
    digitalWrite(6, HIGH);
    delay(100);
    digitalWrite(6, LOW);
    
    // Print it out:
    Serial.print("Received: ");
    Serial.println(payload);
  }
}
