import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/common/perf.dart';
import 'package:lichess_mobile/src/model/relation/relation_ctrl.dart';
import 'package:lichess_mobile/src/model/relation/relation_repository_providers.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';

import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/styles/lichess_colors.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/user/user_screen.dart';
import 'package:lichess_mobile/src/model/user/user.dart';

class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformWidget(androidBuilder: _buildAndroid, iosBuilder: _buildIos);
  }

  Widget _buildIos(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(),
      child: _Body(),
    );
  }

  Widget _buildAndroid(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.following),
      ),
      body: const _Body(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingProvider);

    return following.when(
      data: (data) {
        IList<User> followingUsers = data;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            if (followingUsers.isEmpty) {
              return const Center(
                child: Text("You are not following any user"),
              );
            }
            return SafeArea(
              child: ListView(
                children: [
                  ListSection(
                    children: [
                      for (final user in followingUsers)
                        Slidable(
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            extentRatio: 0.3,
                            children: [
                              SlidableAction(
                                onPressed: (BuildContext context) {
                                  showAdaptiveDialog<void>(
                                    context: context,
                                    builder: (context) => _UnfollowDialog(
                                      title: Text(
                                        'Unfollow ${user.username}?',
                                      ),
                                      onAccept: () async {
                                        final oldState = followingUsers;
                                        setState(() {
                                          followingUsers =
                                              followingUsers.removeWhere(
                                            (v) => v.id == user.id,
                                          );
                                        });

                                        final res = await ref
                                            .read(relationRepositoryProvider)
                                            .unfollow(user.username);
                                        if (res.isError) {
                                          setState(() {
                                            followingUsers = oldState;
                                          });
                                        } else {
                                          ref
                                              .read(
                                                relationCtrlProvider.notifier,
                                              )
                                              .getFollowingOnlines();
                                        }
                                      },
                                    ),
                                  );
                                },
                                backgroundColor: LichessColors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.person_remove,
                                label: 'Unfollow',
                              ),
                            ],
                          ),
                          child: PlatformListTile(
                            onTap: () => {
                              pushPlatformRoute(
                                context,
                                builder: (context) =>
                                    UserScreen(user: user.lightUser),
                              ),
                            },
                            title: Padding(
                              padding: const EdgeInsets.only(right: 5.0),
                              child: Row(
                                children: [
                                  if (user.title != null) ...[
                                    Text(
                                      user.title!,
                                      style: const TextStyle(
                                        color: LichessColors.brag,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Flexible(
                                    child: Text(
                                      user.username,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            subtitle: _UserRating(user: user),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      error: (error, stackTrace) {
        debugPrint(
          'SEVERE: [FollowingScreen] could not following users; $error\n$stackTrace',
        );
        return const Center(child: Text('Could not load following users.'));
      },
      loading: () => const CenterLoadingIndicator(),
    );
  }
}

class _UserRating extends StatelessWidget {
  const _UserRating({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    List<Perf> userPerfs = Perf.values.where((element) {
      final p = user.perfs[element];
      return p != null &&
          p.numberOfGames > 0 &&
          p.ratingDeviation < kClueLessDeviation;
    }).toList(growable: false);

    if (userPerfs.isEmpty) return const SizedBox.shrink();

    userPerfs.sort(
      (p1, p2) => user.perfs[p1]!.numberOfGames
          .compareTo(user.perfs[p2]!.numberOfGames),
    );
    userPerfs = userPerfs.reversed.toList();

    final rating = user.perfs[userPerfs.first]?.rating.toString() ?? '?';
    final icon = userPerfs.first.icon;

    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Text(rating),
      ],
    );
  }
}

class _UnfollowDialog extends StatelessWidget {
  const _UnfollowDialog({
    required this.title,
    required this.onAccept,
  });

  final Widget title;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    void decline() {
      Navigator.of(context).pop();
    }

    void accept() {
      Navigator.of(context).pop();
      onAccept();
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoAlertDialog(
        content: title,
        actions: [
          CupertinoDialogAction(
            onPressed: accept,
            child: Text(context.l10n.accept),
          ),
          CupertinoDialogAction(
            onPressed: decline,
            child: Text(context.l10n.decline),
          ),
        ],
      );
    } else {
      return AlertDialog(
        content: title,
        actions: [
          TextButton(
            onPressed: accept,
            child: Text(context.l10n.accept),
          ),
          TextButton(
            onPressed: decline,
            child: Text(context.l10n.decline),
          ),
        ],
      );
    }
  }
}
