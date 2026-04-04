#include <Wire.h>

/* ================= PM2.5 ================= */
#include "DFRobot_AirQualitySensor.h"
#define I2C_ADDRESS 0x19
DFRobot_AirQualitySensor particle(&Wire, I2C_ADDRESS);

/* ================= ENS160 ================= */
#include <DFRobot_ENS160.h>
DFRobot_ENS160_I2C ENS160(&Wire, 0x53);

/* ================= MPU6050 (RAW) ================= */
#define MPU_ADDR 0x68

void writeReg(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.write(val);
  Wire.endTransmission();
}

int16_t read16(uint8_t reg) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom(MPU_ADDR, 2);
  return (Wire.read() << 8) | Wire.read();
}

/* ================= DS18B20 ================= */
#include <OneWire.h>
#include <DallasTemperature.h>
#define ONE_WIRE_BUS 13
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

/* ================= SETUP ================= */
void setup() {
  Serial.begin(115200);
  Wire.begin(4, 15);
  Wire.setClock(100000);
  delay(200);

  /* ----- MPU6050 RAW INIT ----- */
  writeReg(0x6B, 0x00); // wake up
  delay(100);
  writeReg(0x1C, 0x10); // accel ±8g
  writeReg(0x1B, 0x08); // gyro ±500 dps
  Serial.println("MPU6050 RAW ready");

  /* ----- PM2.5 ----- */
  while (!particle.begin()) {
    Serial.println("NO Devices !");
    delay(1000);
  }
  Serial.println("PM sensor begin success!");
  Serial.print("version is : ");
  Serial.println(particle.gainVersion());

  /* ----- ENS160 ----- */
  while (NO_ERR != ENS160.begin()) {
    Serial.println("ENS160 failed");
    delay(3000);
  }
  Serial.println("ENS160 Begin ok!");
  ENS160.setPWRMode(ENS160_STANDARD_MODE);
  ENS160.setTempAndHum(25.0, 50.0);

  /* ----- DS18B20 ----- */
  sensors.begin();

  Serial.println("All sensors initialized\n");
}

/* ================= LOOP ================= */
void loop() {

  /* ----- PM2.5 ----- */
  Serial.print("PM2.5: ");
  Serial.println(particle.gainParticleConcentration_ugm3(PARTICLE_PM2_5_STANDARD));

  Serial.print("PM1.0: ");
  Serial.println(particle.gainParticleConcentration_ugm3(PARTICLE_PM1_0_STANDARD));

  Serial.print("PM10 : ");
  Serial.println(particle.gainParticleConcentration_ugm3(PARTICLE_PM10_STANDARD));

  /* ----- ENS160 ----- */
  Serial.print("AQI: ");
  Serial.println(ENS160.getAQI());

  Serial.print("TVOC: ");
  Serial.println(ENS160.getTVOC());

  Serial.print("eCO2: ");
  Serial.println(ENS160.getECO2());

  /* ----- MPU6050 RAW READ ----- */
  int16_t ax = read16(0x3B);
  int16_t ay = read16(0x3D);
  int16_t az = read16(0x3F);

  int16_t gx = read16(0x43);
  int16_t gy = read16(0x45);
  int16_t gz = read16(0x47);

  Serial.print("RAW Accel: ");
  Serial.print(ax); Serial.print(", ");
  Serial.print(ay); Serial.print(", ");
  Serial.println(az);

  Serial.print("RAW Gyro: ");
  Serial.print(gx); Serial.print(", ");
  Serial.print(gy); Serial.print(", ");
  Serial.println(gz);

  /* ----- DS18B20 ----- */
  sensors.requestTemperatures();
  Serial.print("Temp C: ");
  Serial.print(sensors.getTempCByIndex(0));
  Serial.print(" F: ");
  Serial.println(sensors.getTempFByIndex(0));

  Serial.println("\n----------------------\n");

  delay(3000);
}
