/**********************************************************************************************
 * Code to read the unique MAC address from a 11AA02E48 and write it to a MCP79410
 *
 * Ian Chilton <ian@ichilton.co.uk>
 * 08/11/2011
 *
 * The MCP7941x is an I2C RTC chip which also includes 1K of EEPROM,
 * 64 bytes of SRAM and a Unique ID.
 * 
 * There are 3 flavours of the MCP7941x, which differ in the Unique ID content:
 * MCP79410 - Blank
 * MCP79411 - EUI-48 Mac Address
 * MCP79412 - EUI-64 Mac Address
 *
 * This code is mainly aimed at the MCP79410 which has no ID in - it's purpose is to
 * read the unique ID from an onboard 11AA02E48 and write it to the unique area in
 * the MCP79410 so it effectively becomes a MCP79411.
 *
 * If the code detects a mac address is already there (0x2b isn't 0xff), it won't do anything.
 *
 * If it detects 0x00 or 0xff from the 11AA02E48, it assumes no 11AA02E48 is present and stops.
 *
 * If the MCP7941x is blank and it successfully gets a mac from the 11AA02E48 then it
 * will unlock the unique id area and write in the mac address obtained from the 11AA02E48.
 *
 * After write, hitting the reset should initiate the process again, but should now find a
 * mac address in the MCP7941x.
 *
 * All of the above procedure is ran once on boot. After that, it will flash the red and green
 * led's (digital pins 5 & 6) and give serial output on 9600 baud to show life.
 *
 * The mcp7941x chip uses an I2C address of 0x57 for the EEPROM and 0x6f for the RTC and SRAM
 * (the Wire library takes care of adding a LSB for read/write selection)
 *
 * The 11AA02E48 should be on digital pin 7.
 *
 * MAC addresses seem to start with 00:04:A3 which is correctly from their
 * allocation: http://hwaddress.com/?q=microchip
 *
 * PLEASE NOTE: This requires Andrew Lindsay's NanodeMAC and EtherShield libraries in your
 * Arduino libraries directory.
 *
 * You can download them from here:
 * https://github.com/thiseldo/NanodeMAC
 * https://github.com/thiseldo/EtherShield
 *
 **********************************************************************************************/

#include "Wire.h"
#include <NanodeMAC.h>
#include <EtherShield.h>

// I2C Addresses:
#define MCP7941x_EEPROM_I2C_ADDR 0x57
#define MCP7941x_RTC_I2C_ADDR 0x6f

// Memory location of the mac address:
// (starts at 0xF0 but first 2 bytes are empty on the MCP79411)
#define MAC_LOCATION 0xF2

// Set the buffer size:
#define BUFFER_SIZE 750

// Array for the mac address:
static uint8_t mymac[6] = { 0,0,0,0,0,0 };

// DHCP Details:
static uint8_t myip[4] = { 0,0,0,0 };
static uint8_t mynetmask[4] = { 0,0,0,0 };
static uint8_t gwip[4] = { 0,0,0,0};
static uint8_t dnsip[4] = { 0,0,0,0 };
static uint8_t dhcpsvrip[4] = { 0,0,0,0 };

static uint8_t buf[BUFFER_SIZE+1];


// Function to print out the mac address:
void displayMacAddress(byte *mac_address)
{
  // Print the mac address:
  for( int i=0; i<6; i++ )
  {
    if (mac_address[i] < 10)
    {
      Serial.print(0);  
    }
    
    Serial.print( mac_address[i], HEX );
    Serial.print( i < 5 ? ":" : "" );
  }

  Serial.println();
}


// Display an IP Address:
void displayIPAddress( uint8_t *ip_address ) {
  for( int i = 0; i < 4; i++ )
  {
    Serial.print( ip_address[i], DEC );
    
    if( i < 3 )
      Serial.print( "." );
  }
}


// Function to read the mac address from the MCP7941x:
void getMacAddress(byte *mac_address)
{ 
  Wire.beginTransmission(MCP7941x_EEPROM_I2C_ADDR);
  Wire.send(MAC_LOCATION);
  Wire.endTransmission();

  Wire.requestFrom(MCP7941x_EEPROM_I2C_ADDR, 6);

  for( int i=0; i<6; i++ )
  {
    mac_address[i] = Wire.receive();
  }
}


// Unlock the unique id area and write in the mac address:
void writeMacAddress(byte *mac_address)
{
  Serial.println("Unlocking MCP7941x");

  Wire.beginTransmission(MCP7941x_RTC_I2C_ADDR);
  Wire.send(0x09);
  Wire.send(0x55);
  Wire.endTransmission();

  Wire.beginTransmission(MCP7941x_RTC_I2C_ADDR);
  Wire.send(0x09);
  Wire.send(0xAA);
  Wire.endTransmission();

  Serial.println("Writing MAC Address to MCP7941x"); 
  Wire.beginTransmission(MCP7941x_EEPROM_I2C_ADDR);
  Wire.send(0xF2);
  
  for( int i=0; i<6; i++ )
  {
    Wire.send(mac_address[i]);
  }
  
  Wire.endTransmission();
  
  Serial.println("Write Complete");
}


void setup()
{
  Wire.begin();
  Serial.begin(9600);

  // Turn LED's On:
  digitalWrite(5, HIGH);
  digitalWrite(6, HIGH);
  
  Serial.println("Welcome to Nanode RF");
  Serial.println();
  
  // LED Pins:
  pinMode(5, OUTPUT);
  pinMode(6, OUTPUT);
  
  // Get the mac address and store in mymac:
  getMacAddress(mymac);
  
  // If the mac address is empty:
  if (mymac[0] == 0xff)
  {
    Serial.println("MAC Address in MCP7941x is empty - attempting to read address from 11AA02E48.");  

    NanodeMAC mac( mymac );
    
    // Check if a mac address has been returned:
    if ((mymac[0] != 0x00 && mymac[0] != 0xff) ||
        (mymac[1] != 0x00 && mymac[1] != 0xff) ||
        (mymac[2] != 0x00 && mymac[2] != 0xff) ||
        (mymac[3] != 0x00 && mymac[3] != 0xff) ||
        (mymac[4] != 0x00 && mymac[4] != 0xff) ||
        (mymac[5] != 0x00 && mymac[5] != 0xff))
    {
      Serial.print("MAC address from 11AA02E48: ");
      displayMacAddress(mymac);
      
      // Attempt to write mac address to MCP7941x:
      writeMacAddress(mymac);
    }
    else
    {
      Serial.println("No MAC address available from 11AA02E48");
    }  
  }
  
  // If there is no MCP7941x chip fitted:
  else if (mymac[0] == 0x00 &&
           mymac[1] == 0x00 &&
           mymac[2] == 0x00 &&
           mymac[3] == 0x00 &&
           mymac[4] == 0x00 &&
           mymac[5] == 0x00)
  {
    Serial.println("No MCP7941x Installed");
  }
  
  else
  {
    Serial.print("MAC Address from MCP7941x: ");

    displayMacAddress(mymac);
    Serial.println();
  }


  // If we have a mac address, try and initialise the ethernet and get DHCP:
  if ((mymac[0] != 0x00 && mymac[0] != 0xff) ||
      (mymac[1] != 0x00 && mymac[1] != 0xff) ||
      (mymac[2] != 0x00 && mymac[2] != 0xff) ||
      (mymac[3] != 0x00 && mymac[3] != 0xff) ||
      (mymac[4] != 0x00 && mymac[4] != 0xff) ||
      (mymac[5] != 0x00 && mymac[5] != 0xff))
  {
    // Create instance of the EtherShield Library:
    EtherShield es=EtherShield();

    // Initialise SPI interface:
    es.ES_enc28j60SpiInit();

    // Initialize ENC28J60:
    Serial.println("Initialising ENC28J60");
    es.ES_enc28j60Init(mymac,8);
  
    Serial.print( "ENC28J60 version " );  
    Serial.println( es.ES_enc28j60Revision(), HEX);
  
    if( es.ES_enc28j60Revision() > 0 )
    {
      Serial.println("Requesting network details from DHCP Server");
      
      if( es.allocateIPAddress(buf, BUFFER_SIZE, mymac, 80, myip, mynetmask, gwip, dhcpsvrip, dnsip ) > 0 )
      {
        // Display the results:
        Serial.print( "My IP: " );
        displayIPAddress( myip );
        Serial.println();

        Serial.print( "Netmask: " );
        displayIPAddress( mynetmask );
        Serial.println();

        Serial.print( "DNS IP: " );
        displayIPAddress( dnsip );
        Serial.println();

        Serial.print( "GW IP: " );
        displayIPAddress( gwip );
        Serial.println();
      }
    
      else
      {
        Serial.println("Failed to contact DHCP server - please check your network connection.");
      }
    }
    else
    {
      Serial.println( "Failed to access the ENC28J60.");
    }
  }
}

void loop()
{
  Serial.print(".");
  
  // RED:
  digitalWrite(5, HIGH);
  digitalWrite(6, LOW);
 
  delay(500);

  // GREEN:
  digitalWrite(6, HIGH);
  digitalWrite(5, LOW);
 
  delay(500);
}

