import UIKit

class ShopListViewController: UIViewController,
	UITableViewDelegate, UITableViewDataSource {
	
	@IBOutlet weak var tableView: UITableView!
	
	var yls: YahooLocalSearch = YahooLocalSearch()
	var loadDataObserver: NSObjectProtocol?
	var refreshObserver: NSObjectProtocol?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Pull to Refreshコントロール初期化
		let refreshControl = UIRefreshControl()
		refreshControl.addTarget(self,
			action: "onRefresh:", forControlEvents: .ValueChanged)
		self.tableView.addSubview(refreshControl)
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		// 読込完了通知を受信した時の処理
		loadDataObserver = NSNotificationCenter.defaultCenter().addObserverForName(
			yls.YLSLoadCompleteNotification,
			object: nil,
			queue: nil,
			usingBlock: {
				(notification) in
				
				// 店舗ID（Gid）が指定されたいたらその順番に並べ替える
				if self.yls.condition.gid != nil {
					self.yls.sortByGid()
				}
				
				self.tableView.reloadData()
				
				// エラーがあればダイアログを開く
				if notification.userInfo != nil {
					if let userInfo = notification.userInfo as? [String: String!] {
						if userInfo["error"] != nil {
							let alertView = UIAlertController(title: "通信エラー",
								message: "通信エラーが発生しました。",
								preferredStyle: .Alert)
							alertView.addAction(
								UIAlertAction(title: "OK", style: .Default) {
									action in return
								}
							)
							self.presentViewController(alertView,
								animated: true, completion: nil)
						}
					}
				}
			}
		)
		
		if yls.shops.count == 0 {
			if self.navigationController is FavoriteNavigationController {
				// お気に入り: お気に入りから検索条件を作って検索
				loadFavorites()
				// ナビゲーションバータイトル設定
				self.navigationItem.title = "お気に入り"
			} else {
				// 検索: 設定された検索条件から検索
				yls.loadData(reset: true)
				// ナビゲーションバータイトル設定
				self.navigationItem.title = "店舗一覧"
			}
		}
	}
	
	override func viewWillDisappear(animated: Bool) {
		// 通知の監視を終了
		NSNotificationCenter.defaultCenter().removeObserver(self.loadDataObserver!)
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}
	
	// MARK: - アプリケーションロジック
	
	func loadFavorites(){
		// お気に入りをUser Defaultsから読み込む
		Favorite.load()
		// お気に入りがあれば店舗ID（Gid）一覧を作成して検索を実行する
		if Favorite.favorites.count > 0 {
			// お気に入り一覧を表現する検索条件オブジェクト
			var condition = QueryCondition()
			// favoritesプロパティの配列の中身を「,」で結合して文字列にする
			condition.gid = join(",", Favorite.favorites)
			// 検索条件を設定して検索実行
			yls.condition = condition
			yls.loadData(reset: true)
		} else {
			// お気に入りがなければ検索を実行せずAPI読込完了通知
			NSNotificationCenter.defaultCenter().postNotificationName(
				yls.YLSLoadCompleteNotification, object: nil)
		}
	}
	
	// Pull to Refresh
	func onRefresh(refreshControl: UIRefreshControl){
		// UIRefreshControlを読込中状態にする
		refreshControl.beginRefreshing()
		// 終了通知を受信したらUIRefreshControlを停止する
		refreshObserver = NSNotificationCenter.defaultCenter().addObserverForName(
			yls.YLSLoadCompleteNotification,
			object: nil,
			queue: nil,
			usingBlock: {
				notification in
				// 通知の待ち受けを終了
				NSNotificationCenter.defaultCenter().removeObserver(self.refreshObserver!)
				// UITefreshControlを停止する
				refreshControl.endRefreshing()
		})
		
		if self.navigationController is FavoriteNavigationController {
			// お気に入り: User Defaultsからお気に入り一覧を再取得してAPI実行する
			loadFavorites()
		} else {
			// 検索: そのまま再取得する
			yls.loadData(reset: true)
		}
	}
	
	// MARK: - UITableViewDelegate
	func tableView(tableView: UITableView,
		heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
			// セルの高さを返す
			return 100
	}
	
	func tableView(tableView: UITableView,
		didSelectRowAtIndexPath indexPath: NSIndexPath) {
			// セルの選択状態を解除する
			tableView.deselectRowAtIndexPath(indexPath, animated: true)
			// Segueを実行する
			performSegueWithIdentifier("PushShopDetail", sender: indexPath)
	}
	
	// MARK: - UITableViewDataSource
	func tableView(tableView: UITableView,
		numberOfRowsInSection section: Int) -> Int {
			if section == 0 {
				// セルの数は店舗数
				return yls.shops.count
			}
			// 通常はここに到達しない
			return 0
	}
	func tableView(tableView: UITableView,
		cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
			if indexPath.section == 0 {
				if indexPath.row < yls.shops.count {
					// rowが店舗数以下なら店舗セルを返す
					let cell = tableView.dequeueReusableCellWithIdentifier("ShopListItem") as ShopListItemTableViewCell
					cell.shop = yls.shops[indexPath.row]
					// まだ残りがあって、現在の列の下の店舗が3つ以下になったら追加取得
					if yls.shops.count < yls.total {
						if yls.shops.count - indexPath.row <= 4 {
							yls.loadData()
						}
					}
					return cell
				}
			}
			// 通常はここに到達しない
			return UITableViewCell()
	}
	
	// MARK: - Navigation
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "PushShopDetail" {
			let vc = segue.destinationViewController as ShopDetailViewController
			if let indexPath = sender as? NSIndexPath {
				vc.shop = yls.shops[indexPath.row]
			}
		}
	}
}

