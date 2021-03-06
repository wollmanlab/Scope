/*
 * This is a modification of the "standard" Micro-Manager Aruino firmware. 
 * 
 * This goal of the application is to set the digital output on pins 8-13 
 * This can be accomplished in three ways.  First, a serial command can directly set
 * the digital output pattern.  Second, a series of patterns can be stored in the 
 * Arduino and TTLs coming in on pin 2 will then trigger to the consecutive pattern (trigger mode).
 * Third, intervals between consecutive patterns can be specified and paterns will be 
 * generated at these specified time points (timed trigger mode).
 *
 * Interface specifications:
 * digital pattern specification: single byte, bit 0 corresponds to pin 8, 
 *   bit 1 to pin 9, etc..  Bits 7 and 8 will not be used (and should stay 0).
 *
 * Set digital output command: 1p
 *   Where p is the desired digital pattern.  Controller will return 1 to 
 *   indicate succesfull execution.
 *
 * Get digital output command: 2
 *   Controller will return 2p.  Where p is the current digital output pattern
 *
 * Set Analogue output command: 3xvv
 *   Where x is the output channel (either 1 or 2), and vv is the output in a 
 *   12-bit significant number.
 *   Controller will return 3xvv:
 *
 * Get Analogue output:  4
 *
 *
 * Set digital patten for triggered mode: 5xd 
 *   Where x is the number of the pattern (currently, 12 patterns can be stored).
 *   and d is the digital pattern to be stored at that position.  Note that x should
 *   be the real number (i.e., not  ASCI encoded)
 *   Controller will return 5xd 
 *
 * Set the Number of digital patterns to be used: 6x
 *   Where x indicates how many digital patterns will be used (currently, up to 12
 *   patterns maximum).  In triggered mode, after reaching this many triggers, 
 *   the controller will re-start the sequence with the first pattern.
 *   Controller will return 6x
 *
 * Skip trigger: 7x
 *   Where x indicates how many digital change events on the trigger input pin
 *   will be ignored.
 *   Controller will respond with 7x
 *
 * Start trigger mode: 8
 *   Controller will return 8 to indicate start of triggered mode
 *   Stop triggered a 9. Trigger mode will  supersede (but not stop) 
 *   blanking mode (if it was active)
 * 
 * Stop Trigger mode: 9
 *   Controller will return 9x where x is the number of triggers received during the last
 *   trigger mode run
 *
 * Set time interval for timed trigger mode: 10xtt
 *   Where x is the number of the interval (currently, 12 intervals can be stored)
 *   and tt is the interval (in ms) in Arduino unsigned int format.  
 *   Controller will return 10x
 *
  * Sets how often the timed pattern will be repeated: 11x
 *   This value will be used in timed-trigger mode and sets how often the output
 *   pattern will be repeated. 
 *   Controller will return 11x
 *  
 * Starts timed trigger mode: 12
 *   In timed trigger mode, digital patterns as set with function 5 will appear on the 
 *   output pins with intervals (in ms) as set with function 10.  After the number of 
 *   patterns set with function 6, the pattern will be repeated for the number of times
 *   set with function 11.  Any input character (which will be processed) will stop 
 *   the pattern generation.
 *   Controller will retun 12.
 * 
 * Start blanking Mode: 20
 *   In blanking mode, zeroes will be written on the output pins when the trigger pin
 *   is low, when the trigger pin is high, the pattern set with command #1 will be 
 *   applied to the output pins. 
 *   Controller will return 20
 *
 * Stop blanking Mode: 21
 *   Stops blanking mode.  Controller returns 21
 *
 * Blanking mode trigger direction: 22x
 *   Sets whether to blank on trigger high or trigger low.  x=0: blank on trigger high,
 *   x=1: blank on trigger low.  x=0 is the default
 *   Controller returns 22
 *
 * 
 * Get Identification: 30
 *   Returns (asci!) MM-Ard\r\n
 *
 * Get Version: 31
 *   Returns: version number (as ASCI string) \r\n
 *
 * Read digital state of analogue input pins 0-5: 40
 *   Returns raw value of PINC (two high bits are not used)
 *
 * Read analogue state of pint pins 0-5: 41x
 *   x=0-5.  Returns analogue value as a 10-bit number (0-1023)
 *
 *
 * 
 * Possible extensions:
 *   Set and Get Mode (low, change, rising, falling) for trigger mode
 *   Get digital patterm
 *   Get Number of digital patterns
 */

#include <Adafruit_DotStar.h>
#include <stdlib.h>
#include <SPI.h>

#define NUMPIXELS 255
#define DATAPIN 3
#define CLOCKPIN 4


Adafruit_DotStar strip = Adafruit_DotStar(NUMPIXELS, DATAPIN, CLOCKPIN, DOTSTAR_BRG);

   
   unsigned int version_ = 2;
   
   // pin on which to receive the trigger (2 and 3 can be used with interrupts, although this code does not use interrupts)
   int inPin_ = 2;
   
   // to read out the state of inPin_ faster, use 
   int inPinBit_ = 1 << inPin_;  // bit mask 
   
   const int SEQUENCELENGTH = 48;  // this should be good enough for everybody;)
   byte triggerPattern_[SEQUENCELENGTH] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
   unsigned int triggerDelay_[SEQUENCELENGTH] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
   int patternLength_ = 0;
   byte repeatPattern_ = 0;
   volatile int triggerNr_; // total # of triggers in this run (0-based)
   volatile int sequenceNr_; // # of trigger in sequence (0-based)
   int skipTriggers_ = 0;  // # of triggers to skip before starting to generate patterns
   byte currentPattern_ = 0;
   const unsigned long timeOut_ = 1000;
   bool blanking_ = false;
   bool blankOnHigh_ = false;
   bool triggerMode_ = false;
   boolean triggerState_ = false;

// LED related stuff
const int LED_ADDRESSSIZE = 16; // we need 16 integers to 
const int LED_MAXPATTERNSNUM = 30; // should be smaller than 64 or less (if some patterns are still used for regular triggering

byte power=250; 
uint32_t color = 0xFFFFFF;

uint16_t LEDpatterns[][LED_ADDRESSSIZE] = {
{65535,65535,65535,65535,65535,65535,65535,65535,65535,65535,65535,65535,65535,65535,65535,65535}, //all
{8191,0,65520,4095,0,65534,127,64512,8191,61440,4095,65280,63,0,32704,4592}, //top
{57344,65535,15,61440,65535,1,65472,1023,57344,4095,61440,255,65472,57345,32831,15}, //bottom
{65535,65535,65535,0,0,0,0,0,0,0,0,0,0,0,0,0}, // ring
{0,0,0,0,0,0,0,0,0,0,0,0,0,65280,65535,32767}, // central
{65534,255,0,65534,63,57344,65535,0,65504,15,65504,1,2047,65280,61441,769}, //left
{1,65280,65535,1,65472,8191,0,65535,31,65520,31,65534,63488,255,4094,64766}, //right
{15,0,57344,0,0,0,0,0,0,0,0,0,0,0,0,0}, //pizza1
{4064,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  //pizza2
{57344,15,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  //pizza3
{0,4064,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  //pizza4
{0,57344,15,0,0,0,0,0,0,0,0,0,0,0,0,0},  //pizza5
{0,0,4064,0,0,0,0,0,0,0,0,0,0,0,0,0},  //pizza6
{0,0,0,0,0,0,0,0,112,0,8,0,0,0,0,16384},  //pizza7
{0,0,0,0,0,0,0,0,3840,0,0,0,0,0,0,16384},  //pizza8
{0,0,0,0,0,0,0,0,57344,1,0,0,0,0,0,16384},  //pizza9
{0,0,0,0,0,0,0,0,0,60,0,0,0,0,0,16384},  //pizza10
{0,0,0,0,0,0,0,0,0,3840,0,0,0,0,0,16384},  //pizza11
{0,0,0,0,0,0,0,0,0,57344,1,0,0,0,0,16384},  //pizza12
{0,0,0,0,0,0,0,0,0,0,0,32768,1,64,0,16384},  //pizza13
{0,0,0,0,0,0,0,0,0,0,0,0,14,0,0,16384},  //pizza14
{0,0,0,0,0,0,0,0,0,0,0,0,448,0,0,16384},  //pizza15
{0,0,0,0,0,0,0,0,0,0,0,0,3584,0,0,16384},  //pizza16
{0,0,0,0,0,0,0,0,0,0,0,0,49152,1,0,16384},  //pizza17
{0,0,0,0,0,0,0,0,0,0,0,0,0,28,0,16384}  //pizza18
};

// mapCodeToPattern will map a state (as defined by MM in 0-63 to row in LED pattern. 
// To allows for backward compatibility to define some of the patterns as digital out (how MM does that) any pattern that is 0, the index of that pattern is interpreted as digital byte (MM way)
// make sure that 0 is always 0 (so no pins are on)
int mapCodeToPattern[] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}; 
 
 void setup() {
   // Higher speeds do not appear to be reliable
   Serial.begin(57600);
 
   pinMode(8, OUTPUT);
   pinMode(9, OUTPUT);
   pinMode(10, OUTPUT);
   pinMode(11, OUTPUT);
   pinMode(12, OUTPUT);
   pinMode(13, OUTPUT);
   
   // Set analogue pins as input:
   DDRC = DDRC & B11000000;
   // Turn on build-in pull-up resistors
   PORTC = PORTC | B00111111;
   
   #if defined(__AVR_ATtiny85__) && (F_CPU == 16000000L)
    clock_prescale_set(clock_div_1); // Enable 16 MHz on Trinket
   #endif

   strip.begin(); // Initialize pins for output
   strip.clear();
   strip.setBrightness(200); 
   strip.show(); 
 }
 
 void loop() {
   if (Serial.available() > 0) {
     int inByte = Serial.read();
     switch (inByte) {
       
       // Set digital output
       case 1 :
          if (waitForSerial(timeOut_)) {
            currentPattern_ = Serial.read();
            if (!blanking_)
              actionByCode(currentPattern_);
            Serial.write( byte(1));
          }
          break;
          
       // Get digital output
       case 2:
          Serial.write( byte(2));
          Serial.write( PORTB);
          break;
          
       // Set Analogue output (TODO: save for 'Get Analogue output')
       case 3:
         if (waitForSerial(timeOut_)) {
           int channel = Serial.read();
           if (waitForSerial(timeOut_)) {
              byte msb = Serial.read();
              msb &= B00001111;
              if (waitForSerial(timeOut_)) {
                byte lsb = Serial.read();
                //analogueOut(channel, msb, lsb);
                Serial.write( byte(3));
                Serial.write( channel);
                Serial.write(msb);
                Serial.write(lsb);
              }
           }
         }
         break;
         
       // Sets the specified digital pattern
       case 5:
          if (waitForSerial(timeOut_)) {
            int patternNumber = Serial.read();
            if ( (patternNumber >= 0) && (patternNumber < SEQUENCELENGTH) ) {
              if (waitForSerial(timeOut_)) {
                triggerPattern_[patternNumber] = Serial.read();
                triggerPattern_[patternNumber] = triggerPattern_[patternNumber] & B00111111;
                Serial.write( byte(5));
                Serial.write( patternNumber);
                Serial.write( triggerPattern_[patternNumber]);
                break;
              }
            }
          }
          Serial.write( "n:");//Serial.print("n:");
          break;
          
       // Sets the number of digital patterns that will be used
       case 6:
         if (waitForSerial(timeOut_)) {
           int pL = Serial.read();
           if ( (pL >= 0) && (pL <= 12) ) {
             patternLength_ = pL;
             Serial.write( byte(6));
             Serial.write( patternLength_);
           }
         }
         break;
         
       // Skip triggers
       case 7:
         if (waitForSerial(timeOut_)) {
           skipTriggers_ = Serial.read();
           Serial.write( byte(7));
           Serial.write( skipTriggers_);
         }
         break;
         
       //  starts trigger mode
       case 8: 
         if (patternLength_ > 0) {
           sequenceNr_ = 0;
           triggerNr_ = -skipTriggers_;
           triggerState_ = digitalRead(inPin_) == HIGH;
           actionByCode(B00000000);
           Serial.write( byte(8));
           triggerMode_ = true;           
         }
         break;
         
         // return result from last triggermode
       case 9:
          triggerMode_ = false;
          actionByCode(B00000000);
          Serial.write( byte(9));
          Serial.write( triggerNr_);
          break;
          
       // Sets time interval for timed trigger mode
       // Tricky part is that we are getting an unsigned int as two bytes
       case 10:
          if (waitForSerial(timeOut_)) {
            int patternNumber = Serial.read();
            if ( (patternNumber >= 0) && (patternNumber < SEQUENCELENGTH) ) {
              if (waitForSerial(timeOut_)) {
                unsigned int highByte = 0;
                unsigned int lowByte = 0;
                highByte = Serial.read();
                if (waitForSerial(timeOut_))
                  lowByte = Serial.read();
                highByte = highByte << 8;
                triggerDelay_[patternNumber] = highByte | lowByte;
                Serial.write( byte(10));
                Serial.write(patternNumber);
                break;
              }
            }
          }
          break;

       // Sets the number of times the patterns is repeated in timed trigger mode
       case 11:
         if (waitForSerial(timeOut_)) {
           repeatPattern_ = Serial.read();
           Serial.write( byte(11));
           Serial.write( repeatPattern_);
         }
         break;

       //  starts timed trigger mode
       case 12: 
         if (patternLength_ > 0) {
           actionByCode(B00000000);
           Serial.write( byte(12));
           for (byte i = 0; i < repeatPattern_ && (Serial.available() == 0); i++) {
             for (int j = 0; j < patternLength_ && (Serial.available() == 0); j++) {
               actionByCode(triggerPattern_[j]);
               delay(triggerDelay_[j]);
             }
           }
           actionByCode(B00000000);
         }
         break;

       // Blanks output based on TTL input
       case 20:
         blanking_ = true;
         Serial.write( byte(20));
         break;
         
       // Stops blanking mode
       case 21:
         blanking_ = false;
         Serial.write( byte(21));
         break;
         
       // Sets 'polarity' of input TTL for blanking mode
       case 22: 
         if (waitForSerial(timeOut_)) {
           int mode = Serial.read();
           if (mode==0)
             blankOnHigh_= true;
           else
             blankOnHigh_= false;
         }
         Serial.write( byte(22));
         break;
         
       // Gives identification of the device
       case 30:
         Serial.println("MM-Ard");
         break;
         
       // Returns version string
       case 31:
         Serial.println(version_);
         break;

       case 40:
         Serial.write( byte(40));
         Serial.write( PINC);
         break;
         
       case 41:
         if (waitForSerial(timeOut_)) {
           int pin = Serial.read();  
           if (pin >= 0 && pin <=5) {
              int val = analogRead(pin);
              Serial.write( byte(41));
              Serial.write( pin);
              Serial.write( highByte(val));
              Serial.write( lowByte(val));
           }
         }
         break;
         
       case 42:
         if (waitForSerial(timeOut_)) {
           int pin = Serial.read();
           if (waitForSerial(timeOut_)) {
             int state = Serial.read();
             Serial.write( byte(42));
             Serial.write( pin);
             if (state == 0) {
                digitalWrite(14+pin, LOW);
                Serial.write( byte(0));
             }
             if (state == 1) {
                digitalWrite(14+pin, HIGH);
                Serial.write( byte(1));
             }
           }
         }
         break;

        /* case 43: // This was to allow loading patterns dynamically - doesn't work with matlab Scp.mmc.writeToSerial
            loadPatternFromSerial(); 
         break; */
       }
    }
    
    // In trigger mode, we will blank even if blanking is not on..
    if (triggerMode_) {
      boolean tmp = PIND & inPinBit_;
      if (tmp != triggerState_) {
        if (blankOnHigh_ && tmp ) {
          PORTB = 0;
        }
        else if (!blankOnHigh_ && !tmp ) {
          actionByCode(0);
        }
        else { 
          if (triggerNr_ >=0) {
            actionByCode(triggerPattern_[sequenceNr_]);
            sequenceNr_++;
            if (sequenceNr_ >= patternLength_)
              sequenceNr_ = 0;
          }
          triggerNr_++;
        }
        
        triggerState_ = tmp;       
      }  
    } else if (blanking_) {
      if (blankOnHigh_) {
        if (! (PIND & inPinBit_))
          actionByCode(currentPattern_);
        else
          actionByCode(0);
      }  else {
        if (! (PIND & inPinBit_))
          actionByCode(0);
        else  
          actionByCode(currentPattern_);
      }
    }
}


 
bool waitForSerial(unsigned long timeOut)
{
    unsigned long startTime = millis();
    while (Serial.available() == 0 && (millis() - startTime < timeOut) ) {}
    if (Serial.available() > 0)
       return true;
    return false;
 }


// If MM 
bool actionByCode(byte actionCode) 
{
  if (mapCodeToPattern[actionCode]>0) 
  {
    turn_led_pattern(mapCodeToPattern[actionCode]); 
  }
  else 
  {
      reset(); 
      PORTB = actionCode & B00111111;; 
      return true; 
  }
}

void turn_led_pattern(int ptrnnum)
{
strip.clear(); 
int led=0;  
ptrnnum=ptrnnum-1; //to move to z based indexing 
for (int i=0; i<16;i++) {
   for (int j=0; j<16;j++) {
    led=i*16+j; 
    if(bitRead(LEDpatterns[ptrnnum][i],j)) {
            strip.setPixelColor(led,color);
      } 
  }
}
strip.show(); 
}

uint32_t byte_to_uint32_t(byte power)
{
   return ((uint32_t)power << 16) | ((uint32_t)power << 8) | (uint32_t)power;
}

void reset()
{
  strip.clear();  // clear all pixel buffer
  digitalWrite(LED_BUILTIN, LOW);
  strip.show();
}

/* potentiallty allowing to load patterns onthe fly - doesn't work with Matlab / mmc.writeToSerial
bool loadPatternFromSerial() {
  for (int r=0; r<LED_MAXPATTERNSNUM; r++) {
    for (int c=0; c<LED_ADDRESSSIZE; c++) {
        if (waitForSerial(timeOut_)) {
          LEDpatterns[r][c] =  Serial.read();
        }
      }
  }
}
*/
/* 
 // This function is called through an interrupt   
void triggerMode() 
{
  if (triggerNr_ >=0) {
    PORTB = triggerPattern_[sequenceNr_];
    sequenceNr_++;
    if (sequenceNr_ >= patternLength_)
      sequenceNr_ = 0;
  }
  triggerNr_++;
}


void blankNormal() 
{
    if (DDRD & B00000100) {
      PORTB = currentPattern_;
    } else
      PORTB = 0;
}

void blankInverted()
{
   if (DDRD & B00000100) {
     PORTB = 0;
   } else {     
     PORTB = currentPattern_;  
   }
}   

*/
  


