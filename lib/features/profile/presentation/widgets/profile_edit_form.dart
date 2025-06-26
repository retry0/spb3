import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/user.dart';
import '../bloc/profile_bloc.dart';

class ProfileEditForm extends StatefulWidget {
  final User user;

  const ProfileEditForm({super.key, required this.user});

  @override
  State<ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends State<ProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String? _avatarUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.Nama);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileUpdating) {
          setState(() {
            _isLoading = true;
          });
        } else if (state is ProfileUpdateSuccess ||
            state is ProfileUpdateError) {
          setState(() {
            _isLoading = false;
          });
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // Avatar URL
                TextFormField(
                  initialValue: _avatarUrl,
                  decoration: const InputDecoration(
                    labelText: 'Avatar URL',
                    hintText: 'Enter URL for your profile picture',
                    prefixIcon: Icon(Icons.image),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _avatarUrl = value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Username field (disabled, just for display)
                TextFormField(
                  initialValue: widget.user.UserName,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.account_circle),
                    helperText: 'Username cannot be changed',
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isLoading
                              ? null
                              : () {
                                // Cancel editing
                                Navigator.of(context).pop();
                              },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveChanges() {
    if (_formKey.currentState?.validate() ?? false) {
      // Create updated user object
      final updatedUser = User(
        Id: widget.user.Id,
        UserName: widget.user.UserName,
        Nama: _nameController.text,
      );

      // Dispatch update event
      context.read<ProfileBloc>().add(
        ProfileUpdateRequested(user: updatedUser),
      );
    }
  }
}
