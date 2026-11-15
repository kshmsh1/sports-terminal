import 'package:flutter/material.dart';

Widget labFrame(String lab) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'The ' + (lab == 'python' ? 'Python Lab' : 'Excel Workspace') +
          ' currently runs in Arcside Web. A native/mobile editor adapter '
          'will be developed after the browser runtime is validated.',
          textAlign: TextAlign.center,
        ),
      ),
    );
