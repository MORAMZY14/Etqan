const functions = require('firebase-functions');
const nodemailer = require('nodemailer');

// Configure your email transporter
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'mudyramzy@gmail.com', // Replace with your email
    pass: '25Y@Galaxy-1999',  // Replace with your email password or app-specific password
  },
});

exports.sendEmailVerificationCode = functions.https.onCall(async (data, context) => {
  const email = data.email;
  const code = data.code;

  const mailOptions = {
    from: 'mudyramzy@gmail.com', // Replace with your email
    to: email,
    subject: 'Your Verification Code',
    text: `Your verification code is ${code}`,
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.toString() };
  }
});
