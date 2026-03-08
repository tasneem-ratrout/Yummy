import 'package:flutter/material.dart';
import 'package:frontend/features/auth/login_screen.dart';
import '../../../core/theme/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Stack(
        children: [

          /// الصورة الخلفية
          Positioned.fill(
            child: Image.asset(
              "assets/images/plates.png",
              fit: BoxFit.cover,
            ),
          ),

          /// طبقة شفافة فوق الصورة
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.09),
            ),
          ),

          
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: ArcClipper(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.45,
                width: double.infinity,
                color: AppColors.background,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      const Text(
                        "Welcome to Yummy",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkBlue,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Recipes, homemade meals,\nand smart calorie tracking with AI.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark.withOpacity(0.65),
                        ),
                      ),

                      const SizedBox(height: 40),

                      const SwipeButton(),

                      const SizedBox(height: 10),

                      
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// القوس
class ArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {

    Path path = Path();

    path.lineTo(0, 80);

    path.quadraticBezierTo(
      size.width / 2,
      -60,
      size.width,
      80,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


class SwipeButton extends StatefulWidget {
  const SwipeButton({super.key});

  @override
  State<SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton> {

  double position = 0;

  Future<void> openLogin() async {

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );

    
    if (!mounted) return;
    setState(() {
      position = 0;
    });
  }

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(
      builder: (context, constraints) {

        double max = constraints.maxWidth - 60;

        return Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.lightBlue.withOpacity(0.30),
            borderRadius: BorderRadius.circular(40),
          ),

          child: Stack(
            children: [

              Center(
                child: Text(
                  "Swipe to get started",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy ,
                    fontSize: 16,
                  ),
                ),
              ),

              Positioned(
                left: position,
                child: GestureDetector(

                  onHorizontalDragUpdate: (details) {

                    setState(() {
                      position += details.delta.dx;

                      if (position < 0) position = 0;
                      if (position > max) position = max;
                    });

                  },

                  onHorizontalDragEnd: (details) async {

                    if (position > max * 0.8) {

                      setState(() {
                        position = max;
                      });

                      await openLogin();

                    } else {

                      setState(() {
                        position = 0;
                      });

                    }

                  },

                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: const BoxDecoration(
                      color: AppColors.navy,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}