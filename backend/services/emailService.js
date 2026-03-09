const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

const sendResetCodeEmail = async (to, code) => {
  await transporter.sendMail({
    from: `"Yummy Support" <${process.env.EMAIL_USER}>`,
    to,
    subject: "Your Yummy password reset code",
    html: `
      <div style="font-family: Arial, sans-serif; padding: 20px;">
        <h2>Password Reset</h2>
        <p>Your verification code is:</p>
        <h1 style="letter-spacing: 6px;">${code}</h1>
        <p>This code will expire in 10 minutes.</p>
      </div>
    `,
  });
};

module.exports = { sendResetCodeEmail };