import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pica_comic/network/download.dart';
import 'package:pica_comic/network/picacg_network/methods.dart';
import 'package:pica_comic/network/picacg_network/models.dart';
import 'package:pica_comic/foundation/ui_mode.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/tools/extensions.dart';
import 'package:pica_comic/views/models/local_favorites.dart';
import 'package:pica_comic/views/page_template/comic_page.dart';
import 'package:pica_comic/views/pic_views/category_comic_page.dart';
import 'package:pica_comic/views/reader/comic_reading_page.dart';
import 'package:pica_comic/views/pic_views/comments_page.dart';
import 'package:pica_comic/views/reader/goto_reader.dart';
import 'package:pica_comic/views/widgets/avatar.dart';
import 'package:pica_comic/views/widgets/side_bar.dart';
import 'package:pica_comic/views/pic_views/widgets.dart';
import 'package:pica_comic/base.dart';
import '../widgets/select_download_eps.dart';
import 'package:pica_comic/views/widgets/show_message.dart';

class PicacgComicPage extends ComicPage<ComicItem> {
  final ComicItemBrief comic;
  const PicacgComicPage(this.comic, {super.key});

  @override
  Row get actions => Row(
        children: [
          Expanded(
            child: ActionChip(
              label: Text(data!.likes.toString()),
              avatar: Icon(
                  (data!.isLiked) ? Icons.favorite : Icons.favorite_border),
              onPressed: () {
                network.likeOrUnlikeComic(comic.id);
                data!.isLiked = !data!.isLiked;
                update();
              },
            ),
          ),
          Expanded(
            child: ActionChip(
              label: Text("收藏".tr),
              avatar: Icon((data!.isFavourite)
                  ? Icons.bookmark
                  : Icons.bookmark_outline),
              onPressed: () {
                network.favouriteOrUnfavouriteComic(comic.id);
                data!.isFavourite = !data!.isFavourite;
                update();
              },
            ),
          ),
          Expanded(
            child: ActionChip(
              label: Text("本地".tr),
              avatar: const Icon(Icons.bookmark_add_outlined),
              onPressed: () => showDialog(
                  context: context,
                  builder: (context) => LocalFavoriteComicDialog(comic)),
            ),
          ),
          Expanded(
            child: ActionChip(
              label: Text(data!.comments.toString()),
              avatar: const Icon(Icons.comment_outlined),
              onPressed: () {
                showComments(Get.context!, comic.id);
              },
            ),
          ),
        ],
      );

  @override
  String get cover => comic.path;

  @override
  FilledButton get downloadButton => FilledButton(
        onPressed: () {
          downloadComic(data!, context, data!.eps);
        },
        child: (downloadManager.downloaded.contains(comic.id))
            ? Text("修改".tr)
            : Text("下载".tr),
      );

  @override
  EpsData? get eps => EpsData(data!.eps, (i) {
        addPicacgHistory(data!);
        Get.to(() =>
            ComicReadingPage.picacg(comic.id, i + 1, data!.eps, comic.title));
      });

  @override
  String? get introduction => data?.description;

  @override
  Future<Res<ComicItem>> loadData() => network.getComicInfo(comic.id);

  @override
  int? get pages => data?.pagesCount;

  @override
  FilledButton get readButton => FilledButton(
        onPressed: () => readPicacgComic(data!, data!.eps),
        child: Text("阅读".tr),
      );

  @override
  SliverGrid recommendationBuilder(data) => SliverGrid(
        delegate: SliverChildBuilderDelegate(
            childCount: data.recommendation.length, (context, i) {
          return PicComicTile(data.recommendation[i]);
        }),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: comicTileMaxWidth,
          childAspectRatio: comicTileAspectRatio,
        ),
      );

  @override
  String get tag => "Picacg Comic Page ${comic.id}";

  @override
  Map<String, List<String>>? get tags => {
        "作者".tr: data!.author.toList(),
        "汉化".tr: data!.chineseTeam.toList(),
        "分类".tr: data!.categories,
        "标签".tr: data!.tags
      };

  @override
  void tapOnTags(String tag) =>
      Get.to(() => CategoryComicPage(tag), preventDuplicates: false);

  @override
  ThumbnailsData? get thumbnailsCreator => null;

  @override
  String? get title => comic.title;

  @override
  Card? get uploaderInfo => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.inversePrimary,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                flex: 0,
                child: Avatar(
                  size: 50,
                  avatarUrl: data!.creator.avatarUrl,
                  frame: data!.creator.frameUrl,
                  couldBeShown: true,
                  name: data!.creator.name,
                  slogan: data!.creator.slogan,
                  level: data!.creator.level,
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 10, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data!.creator.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                          "${data!.time.substring(0, 10)} ${data!.time.substring(11, 19)}更新")
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class ComicPageLogic extends GetxController {
  bool isLoading = true;
  ComicItem? comicItem;
  bool showAppbarTitle = false;
  String? message;
  var tags = <Widget>[];
  var categories = <Widget>[];
  var recommendation = <ComicItemBrief>[];
  var controller = ScrollController();
  var eps = <Widget>[
    ListTile(
      leading: const Icon(Icons.library_books),
      title: Text("章节".tr),
    ),
  ];
  var epsStr = <String>[""];
  void change() {
    isLoading = !isLoading;
    update();
  }
}

void downloadComic(
    ComicItem comic, BuildContext context, List<String> eps) async {
  if (GetPlatform.isWeb) {
    showMessage(context, "Web端不支持下载".tr);
    return;
  }
  for (var i in downloadManager.downloading) {
    if (i.id == comic.id) {
      showMessage(context, "下载中".tr);
      return;
    }
  }
  var downloaded = <int>[];
  if (DownloadManager().downloaded.contains(comic.id)) {
    var downloadedComic = await DownloadManager().getComicFromId(comic.id);
    downloaded.addAll(downloadedComic.downloadedEps);
  }
  if (UiMode.m1(Get.context!)) {
    showModalBottomSheet(
        context: Get.context!,
        builder: (context) {
          return SelectDownloadChapter(eps, (selectedEps) {
            downloadManager.addPicDownload(comic, selectedEps);
            showMessage(context, "已加入下载".tr);
          }, downloaded);
        });
  } else {
    showSideBar(
        Get.context!,
        SelectDownloadChapter(eps, (selectedEps) {
          downloadManager.addPicDownload(comic, selectedEps);
          showMessage(context, "已加入下载".tr);
        }, downloaded),
        useSurfaceTintColor: true);
  }
}

class LocalFavoriteComicDialog extends StatefulWidget {
  const LocalFavoriteComicDialog(this.comic, {Key? key}) : super(key: key);
  final ComicItemBrief comic;

  @override
  State<LocalFavoriteComicDialog> createState() =>
      _LocalFavoriteComicDialogState();
}

class _LocalFavoriteComicDialogState extends State<LocalFavoriteComicDialog> {
  String? message;
  String folderName = "";
  bool addedFavorite = false;

  @override
  Widget build(BuildContext context) {
    var folders = LocalFavoritesManager().folderNames;
    if (folders == null) {
      LocalFavoritesManager().readData().then((value) => setState(() {}));
      return const SizedBox(
        width: 300,
        height: 150,
      );
    }
    return SimpleDialog(
      title: Text("收藏漫画".tr),
      children: [
        SizedBox(
          key: const Key("2"),
          width: 300,
          height: 150,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(5),
                width: 300,
                height: 50,
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: const BorderRadius.all(Radius.circular(16))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text("  选择收藏夹:  ".tr),
                    Text(folderName),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.arrow_drop_down_sharp),
                      onPressed: () {
                        showMenu(
                            context: context,
                            position: RelativeRect.fromLTRB(
                                MediaQuery.of(context).size.width / 2 + 150,
                                MediaQuery.of(context).size.height / 2,
                                MediaQuery.of(context).size.width / 2 - 150,
                                MediaQuery.of(context).size.height / 2),
                            items: [
                              for (var folder in folders)
                                PopupMenuItem(
                                  child: Text(folder),
                                  onTap: () {
                                    setState(() {
                                      folderName = folder;
                                    });
                                  },
                                )
                            ]);
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              FilledButton(
                  onPressed: () async {
                    if (folderName == "") {
                      showMessage(Get.context, "请选择收藏夹");
                      return;
                    }
                    LocalFavoritesManager().addComic(
                        folderName, FavoriteItem.fromPicacg(widget.comic));
                    Get.back();
                  },
                  child: Text("提交".tr))
            ],
          ),
        )
      ],
    );
  }
}
