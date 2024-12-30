# Password-Protected Door Control System

## Description
This project implements a password-protected door control system using an AT89S8253 microcontroller. The system features two buttons and a 7-segment display for user interaction. Upon entering the correct password, the system sends the password to an ESP32-CAM, which captures an image and sends both the password and the image to a web server. Additionally, the data is uploaded to Google Drive and Google Sheets using Google Apps Script.

## Motivation
This project was developed as part of the Microcontroller class at HUST, utilizing the MCS51 microcontroller to control a password-protected door. Our primary goal is to integrate the classic MCS51 with modern IoT and AI technologies. By doing so, we aim to enhance the Human-Machine Interface (HMI) for a more intuitive and efficient user experience. This project not only bridges the gap between traditional microcontroller applications and contemporary technological advancements but also provides a practical example of how legacy systems can be modernized to meet current user expectations.

## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)
- [Future Updates](#future-updates)
- [What Does It Solve](#what-does-it-solve)
- [What Did You Learn](#what-did-you-learn)

## Installation
### Prerequisites
- AT89S8253 microcontroller
- ESP32-CAM module
- 7-segment display
- Two push buttons
- Diode Leds
- Breadboard and jumper wires (PCB Included)
- Internet connection for ESP32-CAM
- Google account for Google Drive and Google Sheets access

### Steps
1. **Hardware Setup**:
   - Connect the 7-segment display and buttons to the AT89S8253 microcontroller.
   - Connect the ESP32-CAM to the microcontroller.
   - Ensure all connections are secure and powered correctly.

2. **Software Setup**:
   - Install the necessary libraries for the ESP32-CAM in the Arduino IDE.
   - Upload the provided code to the AT89S8253 and ESP32-CAM.
   - Set up Google Apps Script to handle data uploads to Google Drive and Google Sheets.

## Usage
1. **Entering the Password**:
   - Use the buttons to enter the password displayed on the 7-segment display.
   - Upon entering the correct password, the system will send the password to the ESP32-CAM.

2. **Capturing and Sending Data**:
   - The ESP32-CAM captures an image upon receiving the password.
   - The password and image are sent to the web server.
   - The data is also uploaded to Google Drive and Google Sheets.

3. **Viewing Data**:
   - Access the web server to view the submitted passwords and images.
   - Check Google Drive and Google Sheets for stored data.

## Contributing
We welcome contributions to this project. Please follow these steps to contribute:
1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Make your changes and commit them (`git commit -m 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Open a pull request.

Special thanks to:

- **[Lai Quoc Dat](https://github.com/capood-ee-hust)**: As a contributor
- **[Nguyen Viet Vuong](https://github.com/nguyenvietvuongbk)**: As mentor of the Project


## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments
- Thanks to the developers of the AT89S8253 and ESP32-CAM libraries.
- Special thanks to the contributors of the Google Apps Script community.

## Future Updates
- **On-Device Face Detection**: Implement face detection directly on the ESP32-CAM for faster results. This will involve using the ESP-WHO library to enable face detection and recognition on the device itself. This update aims to reduce latency and improve the overall performance of the system.

## What Does It Solve
This project addresses the need for a secure and efficient door control system by combining the reliability of the MCS51 microcontroller with the advanced capabilities of IoT and AI. It enhances security by ensuring that only authorized individuals can access the door, and improves user interaction through a more sophisticated HMI.

## What Did You Learn
Through this project, we learned how to:
- Integrate classic microcontroller technology (MCS51) with modern IoT devices (ESP32-CAM).
- Implement face recognition and image capture using the ESP32-CAM.
- Use Google Apps Script to automate data uploads to Google Drive and Google Sheets.
- Enhance the Human-Machine Interface (HMI) for better user interaction and experience.
