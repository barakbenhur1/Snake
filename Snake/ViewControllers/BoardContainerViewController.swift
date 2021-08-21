//
//  ViewController.swift
//  Snake
//
//  Created by Interactech on 12/02/2021.
//

import UIKit
import SpriteKit

// move method enum
enum MoveMethod: String {
    case tap, swipe
}

enum FoodType: String {
    case regular, slow, enamy, enamyDamaged, doNoting, boss
}

class BoardContainerViewController: UIViewController {
    
    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var leftView: UIView!
    @IBOutlet weak var rightView: UIView!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var moveMethodSwitch: UISwitch!
    @IBOutlet weak var highScore: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    
    @IBOutlet weak var bottomHeightConstraint: NSLayoutConstraint!
    
    private var isFromBackground = false
    
    private var board: Board!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let isOn: Bool = UserDefaults.standard.value(forKey: "MoveMethod") as? Bool ?? false
        self.moveMethodSwitch.isOn = isOn
        
        let moveMethod: MoveMethod = isOn ? .swipe : .tap
        
        prepareGameFrame()
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal          // Set defaults to the formatter that are common for showing decimal numbers
        numberFormatter.usesGroupingSeparator = true    // Enabled separator
        numberFormatter.groupingSeparator = ","         // Set the separator to "," (e.g. 1000000 = 1,000,000)
        numberFormatter.groupingSize = 3                // Set the digits between each separator
        
        let score = UserDefaults.standard.value(forKey: "highScore") as? Int ?? 0
        
        let scoreString = numberFormatter.string(from: NSNumber(value: score))!
        
        highScore.text = "High Score: \(scoreString)"
        
        board = Board.create(to: self, numberOfRows: 8, moveMethod: moveMethod, scoreComp: { [weak self] count, time in
            let score = Int(CGFloat((1 + count) * time) * 1.2)
            self?.scoreLabel.text = "Score: \(score)"
            self?.countLabel.text = "Food: \(count)"
        })
        
        board.startOverInformer = {  [weak self] in
            let score = UserDefaults.standard.value(forKey: "highScore") as? Int ?? 0
            
            let scoreString = numberFormatter.string(from: NSNumber(value: score))!
            
            self?.highScore.text = "High Score: \(scoreString)"
            self?.scoreLabel.text = "Score: 0"
            self?.countLabel.text = "Food: 0"
            self?.timeLabel.text = "Time: 0 seconds"
        }
        
        board.timePlayedInformer = {  [weak self] time, count, bonus in
            let score = Int(CGFloat((1 + count) * time) * 1.2)
            self?.scoreLabel.text = "Score: \(score + bonus)"
            self?.timeLabel.text = "Time: \(time) seconds"
        }
    }
    
    
    @objc func stopGame() {
        self.isFromBackground = true
        board.stopGame()
    }
    
    @objc func resumeGame() {
        if isFromBackground {
            isFromBackground = false
            board.resumeGame()
        }
    }
    
    @IBAction func switchMoveMethod(_ sender: UISwitch, forEvent event: UIEvent) {
        
        UserDefaults.standard.set(sender.isOn, forKey: "MoveMethod")
        
        if sender.isOn {
            board.switchMoveMethod(to: .swipe)
        }
        else {
            board.switchMoveMethod(to: .tap)
        }
    }
    
    private func prepareGameFrame() {
        titleView.layer.shadowColor = UIColor.black.cgColor
        titleView.layer.shadowOpacity = 1
        titleView.layer.shadowOffset = .zero
        titleView.layer.shadowRadius = 10
        titleView.layer.shouldRasterize = true
        titleView.layer.rasterizationScale = UIScreen.main.scale
        
        titleView.layer.shadowPath = UIBezierPath(rect: titleView.bounds).cgPath
        
        leftView.layer.shadowColor = UIColor.black.cgColor
        leftView.layer.shadowOpacity = 1
        leftView.layer.shadowOffset = .zero
        leftView.layer.shadowRadius = 10
        leftView.layer.shouldRasterize = true
        leftView.layer.rasterizationScale = UIScreen.main.scale
        
        leftView.layer.shadowPath = UIBezierPath(rect: leftView.bounds).cgPath
        
        rightView.layer.shadowColor = UIColor.black.cgColor
        rightView.layer.shadowOpacity = 1
        rightView.layer.shadowOffset = .zero
        rightView.layer.shadowRadius = 10
        rightView.layer.shouldRasterize = true
        rightView.layer.rasterizationScale = UIScreen.main.scale
        
        rightView.layer.shadowPath = UIBezierPath(rect: rightView.bounds).cgPath
        
        bottomView.layer.shadowColor = UIColor.black.cgColor
        bottomView.layer.shadowOpacity = 1
        bottomView.layer.shadowOffset = .zero
        bottomView.layer.shadowRadius = 10
        bottomView.layer.shouldRasterize = true
        bottomView.layer.rasterizationScale = UIScreen.main.scale
        
        bottomView.layer.shadowPath = UIBezierPath(rect: bottomView.bounds).cgPath
        
        countLabel.text = "Food: 0"
        
        NotificationCenter.default.addObserver(self, selector: #selector(stopGame), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(resumeGame), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
}

class Board  {
    
    // board container view controller
    
    private var containerViewController: BoardContainerViewController!
    
    // board super view
    
    private lazy var superView: UIView = containerViewController!.containerView
    
    // initial params for grid calc
    private var numOfSquaresInRow = 9
    private lazy var squareSize: CGFloat = (superView.frame.width) / CGFloat(numOfSquaresInRow) - 2
    private lazy var boardRatio: CGFloat = (superView.frame.height) / (superView.frame.width)
    private lazy var numOfSquaresInCol: Int = Int(CGFloat(numOfSquaresInRow) * boardRatio) + 1
    
    // calc grid for snake
    private var boardView: UIView!
    
    // center index׳s
    private lazy var rowIndex = numOfSquaresInRow / 2
    private lazy var colIndex = (numOfSquaresInCol / 2) - 1
    
    // snake
    private var snake: Snake!
    
    private var foodSpawnTimer: Timer?
    private var gameTimeTimer: Timer?
    
    private var spawnedFoodDictionary = [String : (assets: (egg: UIImageView?, food: UIImageView), type: FoodType)]()
    
    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(changeDirectionByTap(tapGestureRecognizer:)))
    
    private lazy var tapFire = UITapGestureRecognizer(target: self, action: #selector(fire(gestureRecognizer:)))
    
    private lazy var swipeFireDown = UISwipeGestureRecognizer(target: self, action: #selector(fire(gestureRecognizer:)))
    
    private lazy var swipeFireUp = UISwipeGestureRecognizer(target: self, action: #selector(fire(gestureRecognizer:)))
    
    private lazy var swipeFireLeft = UISwipeGestureRecognizer(target: self, action: #selector(fire(gestureRecognizer:)))
    
    private lazy var swipeFireRight = UISwipeGestureRecognizer(target: self, action: #selector(fire(gestureRecognizer:)))
    
    private lazy var swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(changeDirectionBySwipe(swipeGestureRecognizer:)))
    
    private lazy var swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(changeDirectionBySwipe(swipeGestureRecognizer:)))
    
    private lazy var swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(changeDirectionBySwipe(swipeGestureRecognizer:)))
    
    private lazy var swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(changeDirectionBySwipe(swipeGestureRecognizer:)))
    
    var foodCountComp: ((Int, Int) -> ())?
    
    var startOverInformer: (() -> ())?
    
    var timePlayedInformer: ((Int, Int, Int) -> ())?
    
    private var count: Int = 0
    private var time: Int = 0
    
    private var didLose = false
    
    // MARK: buildBoard
    
    private init() {}
    
    @discardableResult
    static func create(to vc: BoardContainerViewController, numberOfRows: Int, moveMethod: MoveMethod, scoreComp: @escaping ((Int, Int) -> ())) -> Board {
        // Build Container view for board
        
        let board = Board()
        
        board.foodCountComp = scoreComp
        
        board.numOfSquaresInRow = numberOfRows
        
        board.containerViewController = vc
        
        board.superView.layoutIfNeeded()
        
        board.boardView = UIView()
        
        // calc grid for snake
        let table = board.createTable()
        
        table.translatesAutoresizingMaskIntoConstraints = false
        board.boardView.translatesAutoresizingMaskIntoConstraints = false
        
        // add table to board
        board.boardView.addSubview(table)
        
        table.leadingAnchor.constraint(equalTo: board.boardView.leadingAnchor).isActive = true
        table.trailingAnchor.constraint(equalTo: board.boardView.trailingAnchor).isActive = true
        table.topAnchor.constraint(equalTo: board.boardView.topAnchor).isActive = true
        table.bottomAnchor.constraint(equalTo: board.boardView.bottomAnchor).isActive = true
        
        board.boardView.heightAnchor.constraint(equalToConstant: CGFloat(board.numOfSquaresInCol) * board.squareSize).isActive = true
        table.heightAnchor.constraint(equalToConstant: CGFloat(board.numOfSquaresInCol) * board.squareSize).isActive = true
        
        board.boardView.widthAnchor.constraint(equalToConstant: CGFloat(numberOfRows) * board.squareSize).isActive = true
        table.widthAnchor.constraint(equalTo: board.boardView.widthAnchor).isActive = true
        
        // init touch for navigation
        board.switchMoveMethod(to: moveMethod)
        
        board.swipeUp.direction = .up
        board.swipeDown.direction = .down
        board.swipeLeft.direction = .left
        board.swipeRight.direction = .right
        
        board.swipeFireUp.direction = .up
        board.swipeFireDown.direction = .down
        board.swipeFireLeft.direction = .left
        board.swipeFireRight.direction = .right
        
        // add boardView to viewController
        
        board.superView.addSubview(board.boardView)
        
        board.superView.translatesAutoresizingMaskIntoConstraints = false
        
        board.boardView.centerXAnchor.constraint(equalTo: board.superView.centerXAnchor).isActive = true
        board.boardView.centerYAnchor.constraint(equalTo: board.superView.centerYAnchor).isActive = true
        
        board.startGame()
        
        return board
    }
    
    func switchMoveMethod(to method: MoveMethod) {
        
        boardView.removeGestureRecognizer(tap)
        boardView.removeGestureRecognizer(swipeUp)
        boardView.removeGestureRecognizer(swipeDown)
        boardView.removeGestureRecognizer(swipeLeft)
        boardView.removeGestureRecognizer(swipeRight)
        boardView.removeGestureRecognizer(swipeFireUp)
        boardView.removeGestureRecognizer(swipeFireDown)
        boardView.removeGestureRecognizer(swipeFireLeft)
        boardView.removeGestureRecognizer(swipeFireRight)
        boardView.removeGestureRecognizer(tapFire)
        
        switch method {
        case .tap:
            boardView.addGestureRecognizer(tap)
            boardView.addGestureRecognizer(swipeFireUp)
            boardView.addGestureRecognizer(swipeFireDown)
            boardView.addGestureRecognizer(swipeFireLeft)
            boardView.addGestureRecognizer(swipeFireRight)
        case .swipe:
            boardView.addGestureRecognizer(swipeUp)
            boardView.addGestureRecognizer(swipeDown)
            boardView.addGestureRecognizer(swipeLeft)
            boardView.addGestureRecognizer(swipeRight)
            boardView.addGestureRecognizer(tapFire)
        }
    }
    
    private func startGame() {
        self.boardView.subviews.forEach { (subView) in
            if subView is UIImageView{
                subView.removeFromSuperview()
            }
        }
        
        didLose = false
        
        bonusScore = 0
        
        count = 0
        
        spawnTime = 1.6
        
        bossData = nil
        
        timeForBoss = 0
        
        spawnedFoodDictionary = [String : (assets: (egg: UIImageView, food: UIImageView), type: FoodType)]()
        
        startOverInformer?()
        
        addSnakeToBoard()
        
        SoundManager.playSound(named: "Music")
        
        var i = 0
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            if self?.bossData == nil {
                self?.timeForBoss += 1
            }
            else {
                self?.timeForBoss = 0
            }
            i += 1
            self?.time = i
            self?.enamyChanceRatio *= 1.01
            self?.enamyChanceRatio = min(self!.enamyChanceRatio, 0.44)
            self?.timePlayedInformer?(i, self!.count, self!.bonusScore)
        }
        
        gameTimeTimer = timer
        
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private var numToKillBoss = 12
    
    @objc func fire(gestureRecognizer: UITapGestureRecognizer) {
        snake.fire(from: snake.snakeHead, speed: CGFloat(snake.moveSpeed) / 14, bulletHandler: { [self] (bullet) in
            boardView.addSubview(bullet)
        }, checkForCollusionHandler: { [self] (bullet, timer) -> (Bool) in
            guard !didLose else {
                timer.invalidate()
                bullet.removeFromSuperview()
                return false
            }
            if bullet.frame.origin.x < -squareSize || bullet.frame.origin.x > superView.frame.maxX || bullet.frame.origin.y < -squareSize || bullet.frame.origin.y > superView.frame.maxY {
                timer.invalidate()
                bullet.removeFromSuperview()
                return true
            }
            
            if let boss = bossData {
                if boss.image.frame.contains(bullet.center) {
                    timer.invalidate()
                    bullet.removeFromSuperview()
                    
                    bossData?.hits += 1
                    skipMove = true
                    
                    smokeEffect(frame: boss.image.frame, numParticlesToEmit: 4)
                    
                    if bossData?.hits == numToKillBoss {
                        numToKillBoss += 2
                        numToKillBoss = min(numToKillBoss, 28)
                        self.bossData?.timer.invalidate()
                        for food in spawnedFoodDictionary.values {
                            food.assets.food.removeFromSuperview()
                            food.assets.egg?.removeFromSuperview()
                        }
                        spawnedFoodDictionary = [String : (assets: (egg: UIImageView?, food: UIImageView), type: FoodType)]()
                        bossMoveTime -= 0.05
                        bossMoveTime = max(bossMoveTime , snake.moveSpeed - 0.08)
                        bonusScore += 500
                        
                        UIView.animate(withDuration: 0.4) {
                            boss.image.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
                            boss.image.alpha = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            boss.image.removeFromSuperview()
                        }
                        bossData = nil
                        SoundManager.playSound(named: "Music")
                        startSpawningFoodToBoard(timerHandler: { (timer) in
                            foodSpawnTimer = timer
                        })
                    }
                    
                    return true
                }
            }
            
            for keyValue in spawnedFoodDictionary {
                if keyValue.value.assets.food.frame.contains(bullet.center) {
                    guard let egg = keyValue.value.assets.egg else {
                        if spawnedFoodDictionary[keyValue.key]?.type == .enamy {
                            let food = spawnedFoodDictionary[keyValue.key]?.assets.food
                            food?.image = UIImage(named: "enamyDamaged")
                            spawnedFoodDictionary[keyValue.key] = (assets: (egg: nil, food: food!), FoodType(rawValue: FoodType.enamyDamaged.rawValue)!)
                        }
                        else {
                            smokeEffect(frame: keyValue.value.assets.food.frame, imageName: "doNoting", numParticlesToEmit: 18)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                keyValue.value.assets.food.removeFromSuperview()
                            }
                            spawnedFoodDictionary[keyValue.key] = nil
                        }
                        timer.invalidate()
                        bullet.removeFromSuperview()
                        return true
                    }
                    
                    UIView.animate(withDuration: 0.2) {
                        egg.alpha = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        egg.removeFromSuperview()
                    }
                    spawnedFoodDictionary[keyValue.key]?.assets.egg = nil
                    timer.invalidate()
                    bullet.removeFromSuperview()
                    return true
                }
            }
            return false
        }, fireBlocked: { (bullet) in
            bullet.removeFromSuperview()
        })
    }
    
    // MARK: Change Direction Methods - Tap / Swipe
    
    @objc func changeDirectionByTap(tapGestureRecognizer: UITapGestureRecognizer) {
        let loc = tapGestureRecognizer.location(in: boardView)
        
        guard let snakeMoveDiff = calcSnakeMoveDiff(loc) else { return }
        
        switch snakeMoveDiff {
        case (let x , let y) where abs(y) > abs(x):
            if let head = Snake.head, let prv = head.prv {
                guard head.image?.frame.origin.x != prv.image?.frame.origin.x else {
                    return
                }
            }
            
            switch y {
            case ..<0:
                snake!.direction = .down
            default:
                snake!.direction = .up
            }
        default:
            if  let head = Snake.head, let prv = head.prv {
                guard head.image?.frame.origin.y != prv.image?.frame.origin.y else {
                    return
                }
            }
            
            switch snakeMoveDiff.xDiff {
            case ..<0:
                snake!.direction = .right
            default:
                snake!.direction = .left
            }
        }
    }
    
    @objc func changeDirectionBySwipe(swipeGestureRecognizer: UISwipeGestureRecognizer) {
        switch swipeGestureRecognizer.direction {
        case .up, .down:
            if let head = Snake.head, let prv = head.prv {
                guard head.image?.frame.origin.x != prv.image?.frame.origin.x else {
                    return
                }
            }
            
        case .left, .right:
            if let head = Snake.head, let prv = head.prv {
                guard head.image?.frame.origin.y != prv.image?.frame.origin.y else {
                    return
                }
            }
            
        default:
            return
        }
        
        switch swipeGestureRecognizer.direction {
        case .up:
            snake!.direction = .up
        case .down:
            snake!.direction = .down
            
        case .left:
            snake!.direction = .left
        case .right:
            snake!.direction = .right
            
        default:
            return
        }
    }
    
    // calc snake head location diff from a given point
    private func calcSnakeMoveDiff(_ against: CGPoint) -> (xDiff: CGFloat, yDiff: CGFloat)? {
        let snakeHead = Snake.head!.image
        
        let snakeHeadXxis = snakeHead!.frame.origin.x
        let snakeHeadYxis = snakeHead!.frame.origin.y
        
        let yXisDiff = snakeHeadYxis - against.y
        let xXisDiff = snakeHeadXxis - against.x
        
        return (xXisDiff , yXisDiff)
    }
    
    
    // MARK: Create Grid For Board -
    
    // MARK: createStackView ( params { heightAnchorConstant: height for stack view, widthAnchorConstant:  width for stack view, axis: vertical || horizontal } )
    
    private func createStackView(axis: NSLayoutConstraint.Axis) -> UIStackView {
        let stackView = UIStackView()
        stackView.alignment = .fill
        stackView.axis = axis
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }
    
    // MARK: squareView ( params { borderColor: black, borderWidth: 2 } )
    private func squareView() -> UIView {
        let view = UIView()
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.systemGray5.cgColor
        view.heightAnchor.constraint(equalToConstant: squareSize).isActive = true
        view.widthAnchor.constraint(equalToConstant: squareSize).isActive = true
        return view
    }
    
    // MARK: createTableColm
    private func createTableColm() -> UIStackView {
        let stackView = createStackView(axis: .vertical)
        
        for _ in 0..<numOfSquaresInCol {
            let tableCell = squareView()
            stackView.addArrangedSubview(tableCell)
        }
        
        return stackView
    }
    
    // MARK: createTable
    private func createTable() -> UIStackView {
        let mainStackView = createStackView(axis: .horizontal)
        
        for _ in 0..<numOfSquaresInRow {
            let colomStackView = createTableColm()
            mainStackView.addArrangedSubview(colomStackView)
        }
        
        return mainStackView
    }
    
    func stopGame() {
        SoundManager.stop()
        foodSpawnTimer?.invalidate()
        gameTimeTimer?.invalidate()
        bossData?.timer.invalidate()
        snake.stopGame()
    }
    
    private var bonusScore = 0
    
    func resumeGame() {
        SoundManager.play()
        if bossData != nil {
            var reverseX = false
            var reverseY = false
            bossData?.timer = Timer(timeInterval: 0.34, repeats: true) { [self] timer in
                let h = CGFloat.random(in: 0...1) >= 0.5 ? true : false
                
                if h {
                    if (bossData?.image.frame.minX)! >= 0 && (bossData?.image.frame.maxX)! <= superView.frame.maxX - 40 {
                        bossData?.image.frame = CGRect(origin: CGPoint(x: (bossData?.image.frame.origin.x)! + (reverseX ? -squareSize : squareSize), y: (bossData?.image.frame.origin.y)!), size: (bossData?.image.frame.size)!)
                    }
                    else {
                        bossData?.image.frame = CGRect(origin: CGPoint(x: (reverseX ? -squareSize + 60 : superView.frame.maxX - 40 - bossData!.image.frame.width), y: bossData!.image.frame.origin.y), size: bossData!.image.frame.size)
                        reverseX = !reverseX
                    }
                }
                else {
                    if (bossData?.image.frame.minY)! >= 0 && (bossData?.image.frame.maxY)! <= superView.frame.maxY - 160 {
                        var y =  (bossData?.image.frame.origin.y)! + (reverseY ? -squareSize : squareSize)
                        
                        if y < 0 {
                            y = -1
                            reverseY = true
                        }
                        
                        bossData?.image.frame = CGRect(origin: CGPoint(x:  (bossData?.image.frame.origin.x)!, y: y), size: (bossData?.image.frame.size)!)
                    }
                    else {
                        bossData?.image.frame = CGRect(origin: CGPoint(x:  (bossData?.image.frame.origin.x)!, y: (reverseY ? 0 : superView.frame.maxY - 160 -  (bossData?.image.frame.height)!)), size: (bossData?.image.frame.size)!)
                        reverseY = !reverseY
                    }
                }
            }
            
            RunLoop.current.add(bossData!.timer, forMode: .common)
        }
        else {
            self.startSpawningFoodToBoard(timerHandler: { (timer) in
                self.foodSpawnTimer = timer
            })
        }
        
        var i = time
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            if self?.bossData == nil {
                self?.timeForBoss += 1
            }
            else {
                self?.timeForBoss = 0
            }
            i += 1
            self?.time = i
            self?.enamyChanceRatio *= 1.01
            self?.enamyChanceRatio = min(self!.enamyChanceRatio, 0.44)
            self?.timePlayedInformer?(i, self!.count, self!.bonusScore)
        }
        
        gameTimeTimer = timer
        
        RunLoop.current.add(timer, forMode: .common)
        
        snake.resumeGame()
    }
    
    // MARK: Show Lost Popup
    
    private func showLostPopup() {
        
        gameTimeTimer?.invalidate()
        gameTimeTimer = nil
        foodSpawnTimer?.invalidate()
        foodSpawnTimer = nil
        
        let storyBoard: UIStoryboard = UIStoryboard(name: "SnakePopupViewController", bundle: nil)
        guard let lostPopup = storyBoard.instantiateViewController(withIdentifier: "SnakePopupViewController") as? SnakePopupViewController else { return }
        
        lostPopup.closeClousre = { [self] in
            startGame()
        }
        
        lostPopup.modalPresentationStyle = .overFullScreen
        
        lostPopup.count = count
        lostPopup.time = time
        let score = Int(CGFloat((1 + count) * time) * 1.2) + bonusScore
        lostPopup.score = score
        
        containerViewController?.show(lostPopup, sender: nil)
    }
    
    // MARK: Add Snake
    
    private func addSnakeToBoard() {
        let startLocation = CGPoint(x: (CGFloat(rowIndex) * squareSize) + 5, y: (CGFloat(colIndex) * squareSize) + 5)
        let size = squareSize - 10
        let speed = 0.72
        
        enamyChanceRatio = 0
        
        snake = Snake(startLocation: startLocation, size: size, speed:  speed)
        
        snake.bossCheck = { [self] point in
            if let bossData = self.bossData {
                let frame = CGRect(origin: CGPoint(x: bossData.image.frame.origin.x + squareSize, y:  bossData.image.frame.origin.y + squareSize), size: CGSize(width: bossData.image.frame.width - squareSize * 1.2, height: bossData.image.frame.height - squareSize * 1.2))
                let didLose = frame.contains(point)
                if didLose {
                    self.bossData?.timer.invalidate()
                    self.bossData = nil
                }
                return didLose
            }
            return false
        }
        
        boardView.addSubview(snake.snakeHead!)
        
        snake.isFoodThere = { [self] key in
            let isFood = self.spawnedFoodDictionary[key]
            enamyChanceRatio += isFood != nil ? 0.005 : 0
            enamyChanceRatio = min(enamyChanceRatio, 0.44)
            return isFood
        }
        
        snake.didEatFood = { [self] mul, key in
            self.foodSpawnTimer?.invalidate()
            
            let food = self.spawnedFoodDictionary[key]?.assets.food
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                food!.removeFromSuperview()
            }
            
            self.spawnedFoodDictionary[key] = nil
            
            self.spawnTime *= mul
            
            self.spawnTime = max(self.spawnTime, 0.3)
            self.spawnTime = min(self.spawnTime, 1.6)
            
            self.count += 1
            
            self.foodCountComp?(count, self.time)
            
            self.startSpawningFoodToBoard(timerHandler: { (timer) in
                self.foodSpawnTimer = timer
            })
            RunLoop.current.add(self.foodSpawnTimer!, forMode: .common)
        }
        
        snake.addTail = { tail in
            self.boardView.addSubview(tail)
        }
        
        snake.didLose = {
            SoundManager.playSound(named: "GameOver", numberOfLoops: 0, volume: 0.8)
            
            self.bossData?.timer.invalidate()
            self.smokeEffect(frame: self.snake.snakeHead.frame)
            self.didLose = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.showLostPopup()
            }
        }
        
        snake?.startMoving()
        
        startSpawningFoodToBoard(timerHandler: { [weak self] timer in
            self?.foodSpawnTimer = timer
        })
    }
    
    private func smokeEffect(frame: CGRect, imageName: String = "lose", numParticlesToEmit: Int = 0) {
        DispatchQueue.main.async { [self] in
            if let fireParticles = SKEmitterNode(fileNamed: "Smoke") {
                fireParticles.particleTexture = SKTexture(imageNamed: imageName)
                fireParticles.numParticlesToEmit = numParticlesToEmit
                fireParticles.particleScale = 0.6
                fireParticles.alpha = 0.4
                let skView = SKView(frame: frame)
                skView.backgroundColor = .clear
                let scene = SKScene(size: CGSize(width: 10, height: 10))
                scene.backgroundColor = .clear
                skView.presentScene(scene)
                skView.isUserInteractionEnabled = false
                scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                scene.addChild(fireParticles)
                scene.backgroundColor = .clear
                
                boardView.addSubview(skView)
                skView.layer.cornerRadius = squareSize / 2.4
                skView.clipsToBounds = true
                
                skView.backgroundColor = .clear
                
                let peDelay = SKAction.wait(forDuration: 0.7)
                
                let peRemove = SKAction.removeFromParent()
                fireParticles.run(SKAction.sequence([peDelay , peRemove]))
                fireParticles.targetNode?.removeFromParent()
                fireParticles.targetNode = nil
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    skView.removeFromSuperview()
                }
            }
        }
    }
    
    private var spawnTime = 1.6
    private var enamyChanceRatio = 0.0
    
    private var bossData: (timer: Timer, image: UIImageView, hits: Int)?
    
    private var bossMoveTime = 0.44
    
    private var skipMove = false
    
    private var timeForBoss = 0
    
    private func enamyShot() {
        for food in spawnedFoodDictionary.values {
            
            if food.type == .enamyDamaged {
                let didFire  = CGFloat.random(in: 0...1)
                
                if didFire <= 1 {
                    snake.fire(from: food.assets.food, speed: CGFloat(snake.moveSpeed) * 0.5, killSnake: true,
                               bulletHandler: { bullet in
                                self.boardView.addSubview(bullet)
                               }, checkForCollusionHandler: { [self] (bullet, timer) -> (Bool) in
                                guard !didLose else {
                                    timer.invalidate()
                                    bullet.removeFromSuperview()
                                    return false
                                }
                                
                                if bullet.frame.origin.x < -squareSize || bullet.frame.origin.x > superView.frame.maxX || bullet.frame.origin.y < -squareSize || bullet.frame.origin.y > superView.frame.maxY {
                                    timer.invalidate()
                                    bullet.removeFromSuperview()
                                    return true
                                }
                                
                                if let boss = bossData {
                                    if boss.image.frame.contains(bullet.center) {
                                        timer.invalidate()
                                        bullet.removeFromSuperview()
                                        
                                        bossData?.hits += 1
                                        skipMove = true
                                        
                                        smokeEffect(frame: boss.image.frame, numParticlesToEmit: 4)
                                        
                                        if bossData?.hits == numToKillBoss {
                                            numToKillBoss += 2
                                            numToKillBoss = min(numToKillBoss, 28)
                                            self.bossData?.timer.invalidate()
                                            for food in spawnedFoodDictionary.values {
                                                food.assets.food.removeFromSuperview()
                                                food.assets.egg?.removeFromSuperview()
                                            }
                                            spawnedFoodDictionary = [String : (assets: (egg: UIImageView?, food: UIImageView), type: FoodType)]()
                                            bossMoveTime -= 0.05
                                            bossMoveTime = max(bossMoveTime , snake.moveSpeed - 0.08)
                                            bonusScore += 500
                                            boss.image.removeFromSuperview()
                                            bossData = nil
                                            startSpawningFoodToBoard(timerHandler: { (timer) in
                                                foodSpawnTimer = timer
                                            })
                                        }
                                        
                                        return true
                                    }
                                }
                                
                                for keyValue in spawnedFoodDictionary {
                                    if keyValue.value.assets.food.frame.contains(bullet.center) {
                                        guard let egg = keyValue.value.assets.egg else {
                                            if spawnedFoodDictionary[keyValue.key]?.type == .enamy {
                                                let food = spawnedFoodDictionary[keyValue.key]?.assets.food
                                                food?.image = UIImage(named: "enamyDamaged")
                                                spawnedFoodDictionary[keyValue.key] = (assets: (egg: nil, food: food!), FoodType(rawValue: FoodType.enamyDamaged.rawValue)!)
                                            }
                                            else {
                                                smokeEffect(frame: keyValue.value.assets.food.frame, imageName: "doNoting", numParticlesToEmit: 18)
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    keyValue.value.assets.food.removeFromSuperview()
                                                }
                                                spawnedFoodDictionary[keyValue.key] = nil
                                            }
                                            timer.invalidate()
                                            bullet.removeFromSuperview()
                                            return true
                                        }
                                        
                                        UIView.animate(withDuration: 0.2) {
                                            egg.alpha = 0
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            egg.removeFromSuperview()
                                        }
                                        spawnedFoodDictionary[keyValue.key]?.assets.egg = nil
                                        timer.invalidate()
                                        bullet.removeFromSuperview()
                                        return true
                                    }
                                }
                                return false
                               }, fireBlocked: { (bullet) in
                                bullet.removeFromSuperview()
                               })
                }
            }
        }
    }
    
    private var bossSpawnTime = 40
    
    private func startSpawningFoodToBoard(timerHandler: @escaping (Timer) -> ()) {
        
        let timer = Timer(timeInterval: spawnTime, repeats: true) { [self] (timer) in
            
            guard !didLose else { return }
            
            enamyShot()
            
            if timeForBoss >= bossSpawnTime {
                SoundManager.playSound(named: "BossMusic")
                let label = UILabel(frame: CGRect(origin: .init(x: boardView.center.x - (boardView.frame.width - 40) * 0.5, y: boardView.center.y - 80), size: CGSize(width: boardView.frame.width - 40, height: 30)))
                label.text = "BOSS TIME"
                label.font = .boldSystemFont(ofSize: 30)
                label.textColor = .red
                label.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
                label.alpha = 0.1
                
                label.layer.cornerRadius = 0
                label.layer.masksToBounds = false
                label.layer.shadowColor = UIColor.black.cgColor
                label.layer.shadowOpacity = 0.3
                label.layer.shadowOffset = CGSize(width: -20, height: 20)
                label.layer.shadowRadius = 26
                
                label.layer.shadowPath = UIBezierPath(rect: label.bounds).cgPath
                
                label.textAlignment = .center
                boardView.addSubview(label)
                
                boardView.bringSubviewToFront(label)
                
                UIView.animate(withDuration: 0.3) {
                    label.transform = .identity
                    label.alpha = 1
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                    label.text! += " 👹"
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.94) {
                    UIView.animate(withDuration: 0.4) {
                        label.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
                        label.alpha = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        label.removeFromSuperview()
                    }
                }
                
                let boss = PointOnBoard.create(loc: .zero, size: squareSize * 3, image: UIImage(named: FoodType.boss.rawValue)!)
                boss.layer.cornerRadius = 0
                boss.layer.masksToBounds = false
                boss.layer.shadowColor = UIColor.black.cgColor
                boss.layer.shadowOpacity = 0.3
                boss.layer.shadowOffset = CGSize(width: -20, height: 20)
                boss.layer.shadowRadius = 26
                
                boss.layer.shadowPath = UIBezierPath(rect: boss.bounds).cgPath
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    boardView.addSubview(boss)
                    boardView.bringSubviewToFront(boss)
                }
                timer.invalidate()
                
                for food in spawnedFoodDictionary.values {
                    food.assets.food.removeFromSuperview()
                    food.assets.egg?.removeFromSuperview()
                }
                
                spawnedFoodDictionary = [String : (assets: (egg: UIImageView?, food: UIImageView), type: FoodType)]()
                
                var reverseX = false
                var reverseY = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    let bossTimer = Timer(timeInterval: bossMoveTime, repeats: true) { timer in
                        
                        guard !didLose else {
                            timer.invalidate()
                            return
                        }
                        
                        boardView.bringSubviewToFront(boss)
                        
                        let shoot = CGFloat.random(in: 0...1)
                        
                        if shoot < 0.2 {
                            enamyShot()
                        }
                        
                        let action = CGFloat.random(in: 0...1)
                        
                        if action <= 0.14 {
                            snake.fire(from: boss, speed: CGFloat(snake.moveSpeed) * 0.3, killSnake: true,
                                       bulletHandler: { bullet in
                                        boardView.addSubview(bullet)
                                       }, checkForCollusionHandler: { [self] (bullet, timer) -> (Bool) in
                                        guard !didLose else {
                                            timer.invalidate()
                                            bullet.removeFromSuperview()
                                            return false
                                        }
                                        if bullet.frame.origin.x < -squareSize || bullet.frame.origin.x > superView.frame.maxX || bullet.frame.origin.y < -squareSize || bullet.frame.origin.y > superView.frame.maxY {
                                            timer.invalidate()
                                            bullet.removeFromSuperview()
                                            return true
                                        }
                                        
                                        for keyValue in spawnedFoodDictionary {
                                            if keyValue.value.assets.food.frame.contains(bullet.center) {
                                                guard let egg = keyValue.value.assets.egg else {
                                                    if spawnedFoodDictionary[keyValue.key]?.type == .enamy {
                                                        let food = spawnedFoodDictionary[keyValue.key]?.assets.food
                                                        food?.image = UIImage(named: "enamyDamaged")
                                                        spawnedFoodDictionary[keyValue.key] = (assets: (egg: nil, food: food!), FoodType(rawValue: FoodType.enamyDamaged.rawValue)!)
                                                    }
                                                    else {
                                                        smokeEffect(frame: keyValue.value.assets.food.frame, imageName: "doNoting", numParticlesToEmit: 18)
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                            keyValue.value.assets.food.removeFromSuperview()
                                                        }
                                                        spawnedFoodDictionary[keyValue.key] = nil
                                                    }
                                                    timer.invalidate()
                                                    bullet.removeFromSuperview()
                                                    return true
                                                }
                                                
                                                UIView.animate(withDuration: 0.2) {
                                                    egg.alpha = 0
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                    egg.removeFromSuperview()
                                                }
                                                spawnedFoodDictionary[keyValue.key]?.assets.egg = nil
                                                timer.invalidate()
                                                bullet.removeFromSuperview()
                                                return true
                                            }
                                        }
                                        return false
                                       }, fireBlocked: { (bullet) in
                                        bullet.removeFromSuperview()
                                       })
                            
                        }
                        else if action >= 0.92 {
                            addFoodToBoard(imageName: FoodType.enamy.rawValue, eggChance: false)
                        }
                        
                        guard !skipMove else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                bossData?.timer.fire()
                                skipMove = false
                            }
                            return
                        }
                        
                        let h = CGFloat.random(in: 0...1) >= 0.5 ? true : false
                        
                        if h {
                            if boss.frame.minX >= 0 && boss.frame.maxX <= superView.frame.maxX - 40 {
                                boss.frame = CGRect(origin: CGPoint(x: boss.frame.origin.x + (reverseX ? -squareSize : squareSize), y: boss.frame.origin.y), size: boss.frame.size)
                            }
                            else {
                                boss.frame = CGRect(origin: CGPoint(x: (reverseX ? -squareSize + 60 : superView.frame.maxX - 40 - boss.frame.width), y: boss.frame.origin.y), size: boss.frame.size)
                                reverseX = !reverseX
                            }
                        }
                        else {
                            if boss.frame.minY >= 0 && boss.frame.maxY <= superView.frame.maxY - 160 {
                                var y = boss.frame.origin.y + (reverseY ? -squareSize : squareSize)
                                
                                if y < 0 {
                                    y = -1
                                    reverseY = true
                                }
                                
                                boss.frame = CGRect(origin: CGPoint(x: boss.frame.origin.x, y: y), size: boss.frame.size)
                            }
                            else {
                                boss.frame = CGRect(origin: CGPoint(x: boss.frame.origin.x, y: (reverseY ? 0 : superView.frame.maxY - 160 - boss.frame.height)), size: boss.frame.size)
                                reverseY = !reverseY
                            }
                        }
                        
                        for tuple in spawnedFoodDictionary {
                            if boss.frame.contains(tuple.value.assets.food.center) {
                                smokeEffect(frame: tuple.value.assets.food.frame, imageName: "doNoting", numParticlesToEmit: 8)
                                tuple.value.assets.food.removeFromSuperview()
                                spawnedFoodDictionary[tuple.key] = nil
                            }
                        }
                    }
                    bossData = (timer: bossTimer,image: boss, hits: 0)
                    RunLoop.current.add(bossTimer, forMode: .common)
                }
                return
            }
            
            var foodTypeString = FoodType.regular.rawValue
            
            let enamyChance = Double.random(in: 0...1)
            
            if enamyChance < enamyChanceRatio {
                enamyChanceRatio *= 0.88
                foodTypeString = FoodType.enamy.rawValue
            }
            else {
                let spacialFoodChance = Double.random(in: 0...1)
                
                if spacialFoodChance <= 0.04 || spacialFoodChance >= 0.44 && spacialFoodChance < 0.5  || spacialFoodChance >= 0.95 {
                    let isSlow =  Double.random(in: 0...1) > 0.25
                    
                    foodTypeString = isSlow ? FoodType.slow.rawValue : FoodType.doNoting.rawValue
                }
            }
            
            addFoodToBoard(imageName: foodTypeString)
        }
        
        timerHandler(timer)
        
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func addFoodToBoard(imageName: String, eggChance: Bool = true) {
        
        let foodXindex = Int.random(in: 0...numOfSquaresInRow - 1)
        let foodYindex = Int.random(in: 0...numOfSquaresInCol - 1)
        
        let foodPoint = CGPoint(x: (superView.frame.origin.x - 5 + CGFloat(foodXindex) * squareSize), y: (CGFloat(foodYindex) * squareSize))
        
        let food = PointOnBoard.create(loc: foodPoint, size: (squareSize - 10), image: UIImage(named: imageName)!)
        
        let foodLoc = CGPoint(x: Int(foodPoint.x / squareSize), y: Int(foodPoint.y / squareSize))
        
        let foodPart = SnakePart(locationFrame: food.frame, image: food)
        
        let key = PointOnBoard.generateKeyPoint(origin: foodLoc)
        
        guard spawnedFoodDictionary[key] == nil else {
            return
        }
        
        let headXindex: Int = Int(snake.snakeHead!.frame.origin.x / (squareSize))
        let headYindex: Int = Int(snake.snakeHead!.frame.origin.y / (squareSize))
        
        let headPoint = CGPoint(x: headXindex, y: headYindex)
        
        guard !foodLoc.equalTo(headPoint) else {
            return
        }
        
        guard !snake!.touchBody(with: foodPart) else {
            return
        }
        
        let restrictedSpawn = distance(from: CGPoint(x: foodXindex, y: foodYindex), to: CGPoint(x: headXindex, y: headYindex)) <= 2
        
        guard !snake.isInfront(frame: food.frame) && !restrictedSpawn else {
            return
        }
        
        smokeEffect(frame: food.frame, imageName: "egg", numParticlesToEmit: 10)
        
        boardView.addSubview(food)
        
        food.layer.masksToBounds = false
        food.layer.shadowColor = UIColor.black.cgColor
        food.layer.shadowOpacity = 0.48
        food.layer.shadowOffset = .zero
        food.layer.shadowRadius = food.frame.width / 2
        
        food.layer.shadowPath = UIBezierPath(rect: food.bounds).cgPath
        
        var egg: UIImageView? = nil
        
        if eggChance {
            if spawnTime / Double(Int.random(in: 1...6)) <= 0.32 {
                egg = PointOnBoard.create(loc: food.frame.origin, size: squareSize, image: UIImage(named: "egg")!)
                
                egg?.layer.cornerRadius = 0
                
                boardView.addSubview(egg!)
                
                egg!.layer.masksToBounds = false
                egg!.layer.shadowColor = UIColor.gray.cgColor
                egg!.layer.shadowOpacity = 0.4
                egg!.layer.shadowOffset = .zero
                egg!.layer.shadowRadius = egg!.frame.width / 2
                
                egg!.layer.shadowPath = UIBezierPath(rect: egg!.bounds).cgPath
            }
        }
        
        spawnedFoodDictionary[key] = (assets: (egg: egg, food: food), FoodType(rawValue: imageName)!)
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        return sqrt(pow(from.x - to.x, 2) + pow(from.y - to.y, 2))
    }
}

class Snake {
    // direction enum
    enum Direction: Int {
        case up, down, left, right
    }
    
    private enum operation {
        case plus, minus
        
        func performOperation<T: Numeric>(a: T, b: T) -> T {
            switch self {
            case .plus:
                return a + b
            default:
                return a - b
            }
        }
    }
    
    static var head: SnakePart!
    var tail: SnakePart
    
    static var current: SnakePart?
    static var count: Int = 1
    static var index: Int = 0
    
    static var animate = true
    
    // MARK: Add food for snake to eat and grow by make movement faster
    
    var moveSpeed: Double!
    private var initialSpeed : Double!
    
    // snake head parms
    var direction: Direction = .left
    
    var snakeHead: UIImageView!
    
    var isFoodThere: ((String) -> (assets: (egg: UIImageView?, food: UIImageView), type: FoodType)?)?
    var didEatFood: ((Double, String) -> ())!
    var didLose: (() -> ())!
    var addTail: ((UIImageView) -> ())!
    
    private var movementTimer: Timer?
    
    var bodySize: CGFloat!
    
    init(startLocation: CGPoint, size: CGFloat, speed: Double) {
        
        let head = PointOnBoard.create(loc: startLocation, size: size, image: UIImage(named: "snakeHead")!)
        
        bodySize = size
        
        snakeHead = head
        snakeHead.layer.cornerRadius = 0
        snakeHead.layer.masksToBounds = false
        snakeHead.layer.shadowColor = UIColor.black.cgColor
        snakeHead.layer.shadowOpacity = 0.5
        snakeHead.layer.shadowOffset = .zero
        snakeHead.layer.shadowRadius = snakeHead.frame.width / 2
        
        snakeHead.layer.shadowPath = UIBezierPath(rect: snakeHead.bounds).cgPath
        
        moveSpeed = speed
        initialSpeed = speed
        
        let headPart = SnakePart(locationFrame: head.frame, image: head)
        
        Snake.head = headPart
        tail = headPart
        direction = Direction(rawValue: Int.random(in: 0...3))!
        
        Snake.current = Snake.head
        Snake.count = 1
        Snake.index = 0
    }
    
    
    func stopGame() {
        movementTimer?.invalidate()
    }
    
    func resumeGame() {
        startMoving()
    }
    
    static func reset() {
        Snake.current = Snake.head
        Snake.index = 0
    }
    
    func startMoving() {
        let timer = startMovementTimer()
        
        movementTimer = timer
        
        RunLoop.current.add(timer, forMode: .common)
    }
    
    func move(to point: CGPoint, tail: @escaping (UIImageView?) -> ()) {
        
        UIView.animate(withDuration: moveSpeed * 0.35) {
            
            var part = Snake.head
            var frame = part!.image!.frame
            
            DispatchQueue.main.asyncAfter(deadline: .now() + self.moveSpeed * (Snake.animate ? 0.1 : 0.32)) {
                part?.image?.alpha = 1
            }
            
            while let nextPart = self.getNetPart() {
                nextPart.locationFrame = frame
                
                let spin = abs(nextPart.image!.frame.origin.y - part!.image!.frame.origin.y) > abs(nextPart.image!.frame.origin.x - part!.image!.frame.origin.x)
                
                if spin && nextPart.image!.transform.isIdentity  {
                    nextPart.image!.transform = nextPart.image!.transform.rotated(by: CGFloat(Double.pi / 2))
                }
                else if !spin {
                    nextPart.image!.transform = .identity
                }
                
                nextPart.image!.image = UIImage(named: "bodyPart")
                
                nextPart.image!.layer.cornerRadius = nextPart.image!.frame.width / 2
                part!.image!.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner, .layerMaxXMinYCorner]
                
                part = nextPart
                frame = part!.image!.frame
                part!.image?.frame = part!.locationFrame
                
                Snake.animate = true
            }
            
            tail(part!.image!)
            
            Snake.reset()
            
            Snake.head!.image!.frame.origin.x = point.x
            Snake.head!.image!.frame.origin.y = point.y
            
            if Snake.count > 1 {
                part!.image!.layer.cornerRadius = part!.image!.frame.width / 1.4
            }
        }
    }
    
    var bossCheck: ((_ frame: CGPoint) -> (Bool))?
    
    private func startMovementTimer() -> Timer {
        
        return Timer(timeInterval: moveSpeed, repeats: true) { [self] (timer) in
            
            let moveCalc : (_ num: CGFloat, _ op: operation) -> (CGFloat) = { (number: CGFloat, op: operation) in
                return op.performOperation(a: number, b: self.bodySize + 10.0)
            }
            
            var moveInterval: CGFloat = 0
            
            var isInBoard = true
            
            let snakeHead = Snake.head?.image
            
            switch direction {
            case .right:
                snakeHead?.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2))
                moveInterval = moveCalc(snakeHead!.frame.origin.x, .plus)
                isInBoard = Int(moveInterval) < Int(snakeHead!.superview!.frame.origin.x + snakeHead!.superview!.frame.width) - Int(snakeHead!.frame.width)
            case .left:
                snakeHead?.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2))
                moveInterval = moveCalc(snakeHead!.frame.origin.x, .minus)
                isInBoard = Int(moveInterval) > 0
            case .up:
                snakeHead?.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                moveInterval = moveCalc(snakeHead!.frame.origin.y, .minus)
                isInBoard = Int(moveInterval) > 0
            case .down:
                snakeHead?.transform = .identity
                moveInterval = moveCalc(snakeHead!.frame.origin.y, .plus)
                isInBoard = Int(moveInterval) < Int(snakeHead!.superview!.frame.origin.y + snakeHead!.superview!.frame.height) - Int(snakeHead!.frame.height)
            }
            
            guard isInBoard else {
                timer.invalidate()
                didLose()
                return
            }
            
            var movePoint: CGPoint = .zero
            switch direction {
            case  .left, .right:
                movePoint = CGPoint(x: moveInterval, y:  snakeHead!.frame.origin.y)
            case .up, .down:
                movePoint = CGPoint(x: snakeHead!.frame.origin.x , y:  moveInterval)
            }
            
            guard !touchBody(with: Snake.head) else {
                timer.invalidate()
                didLose()
                return
            }
            
            move(to: movePoint) { (tail) in
                addTail(tail!)
            }
            
            if let bossCheck = bossCheck, bossCheck(Snake.head.image!.center) {
                timer.invalidate()
                didLose()
                return
            }
            
            let xFloat: CGFloat = (snakeHead!.frame.origin.x) / (bodySize + 10)
            let yFloat: CGFloat = (snakeHead!.frame.origin.y) / (bodySize + 10)
            
            let point = CGPoint(x: xFloat, y: yFloat)
            
            let key = PointOnBoard.generateKeyPoint(origin: point)
            
            if let asset = isFoodThere!(key) {
                guard asset.assets.egg == nil else {
                    snakeHead?.superview?.bringSubviewToFront(asset.assets.egg!)
                    allowFire = false
                    movementTimer?.invalidate()
                    didLose()
                    return
                }
                eatFood(key: key ,food: asset.assets.food, type: asset.type)
            }
        }
    }
    
    private var allowFire = true
    private var bullets = [UIImageView]()
    
    func fire(from: UIImageView, speed: CGFloat, killSnake: Bool = false, bulletHandler: @escaping (UIImageView) -> (), checkForCollusionHandler:  @escaping (UIImageView, Timer) -> (Bool), fireBlocked: @escaping (UIImageView) -> ()) {
        
        guard allowFire else { return }
        
        let bullet = PointOnBoard.create(loc: from.frame.origin, size: bodySize, image: UIImage(named: killSnake ? "fireBall_2" : "fireBall")!)
        
        bullets.append(bullet)
        
        allowFire = killSnake
        
        bullet.alpha = 0
        
        bulletHandler(bullet)
        
        let fireDirection = killSnake ? Direction(rawValue:  Int.random(in: 0...3))! : direction
        
        let timer = Timer(timeInterval: TimeInterval(speed), repeats: true) { [self] (timer) in
            UIView.animate(withDuration: 0.001) {
                switch fireDirection {
                case .right:
                    bullet.frame.origin.x += bodySize
                case .left:
                    bullet.frame.origin.x -= bodySize
                case .down:
                    bullet.frame.origin.y += bodySize
                case .up:
                    bullet.frame.origin.y -= bodySize
                }
            }
            
            rotateView(targetView: bullet, duration: 0.15)
            
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.03) {
                bullet.alpha = 1
            }
            
            let part = SnakePart(locationFrame: bullet.frame, image: bullet)
            
            if bullets.firstIndex(of: bullet) != nil && snakeHead.frame.contains(bullet.center) && killSnake {
                allowFire = true
                movementTimer?.invalidate()
                didLose()
                return
            }
            
            for fire in bullets {
                if bullet != fire && bullet.frame.contains(fire.center) {
                    timer.invalidate()
                    if let index = bullets.firstIndex(of: bullet) {
                        bullets.remove(at: index)
                    }
                    if let index = bullets.firstIndex(of: fire) {
                        bullets.remove(at: index)
                    }
                    fireBlocked(bullet)
                    fireBlocked(fire)
                    
                    DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.04) {
                        allowFire = true
                    }
                    return
                }
            }
            
            if touchBody(with: part) {
                timer.invalidate()
                if let index =  bullets.firstIndex(of: bullet) {
                    bullets.remove(at: index)
                }
                fireBlocked(bullet)
                
                DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.08) {
                    allowFire = true
                }
            }
            else {
                let finish = checkForCollusionHandler(bullet, timer)
                
                if finish {
                    if let index =  bullets.firstIndex(of: bullet) {
                        bullets.remove(at: index)
                    }
                    DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
                        allowFire = true
                    }
                }
            }
        }
        
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func rotateView(targetView: UIView, duration: Double = 1.0) {
        UIView.animate(withDuration: duration, delay: 0.04, options: .curveLinear, animations: {
            targetView.transform = targetView.transform.rotated(by: CGFloat(Double.pi))
        }) { finished in
            self.rotateView(targetView: targetView, duration: duration)
        }
    }
    
    func eatFood(key: String, food: UIImageView, type: FoodType) {
        
        movementTimer?.invalidate()
        
        let part = PointOnBoard.create(loc: tail.locationFrame.origin, size: bodySize)
        
        switch type {
        case .regular, .slow:
            eat(imageView: part)
        case .enamy, .enamyDamaged:
            snakeHead?.superview?.bringSubviewToFront(food)
            didLose()
            return
        default:
            break
        }
        
        var foodTuple: (mul: Double, key: String)
        
        switch type  {
        case .regular:
            moveSpeed *= 0.96
            foodTuple.mul = 0.98
            foodTuple.key = key
            
        case .slow:
            moveSpeed *= 1.05
            foodTuple.mul = 1.02
            foodTuple.key = key
            
        default:
            foodTuple.mul = 1
            foodTuple.key = key
            break
        }
        
        moveSpeed = max(moveSpeed, 0.2)
        moveSpeed = min(moveSpeed, initialSpeed)
        
        didEatFood(foodTuple.mul, foodTuple.key)
        
        movementTimer = startMovementTimer()
        
        RunLoop.current.add(movementTimer!, forMode: .common)
    }
    
    func eat(imageView: UIImageView) {
        
        let part = SnakePart(locationFrame: tail.locationFrame, image: imageView)
        part.image?.alpha = 0
        
        tail.addBodyPart(part: part)
        
//        print("//////////////////////////////////////////////////////////////////////////////////\neat food at: \(part.printPart())\n")
        
        tail = part
        
        Snake.current = Snake.head
        Snake.count += 1
        Snake.animate = Snake.count != 2
    }
    
    func touchBody(with part: SnakePart) -> Bool {
        Snake.reset()
        
        while let nextPart = getNetPart() {
            if nextPart.image!.frame.contains(part.image!.center) {
                return true
            }
        }
        
        Snake.reset()
        
        return false
    }
    
    func isInfront(frame: CGRect) -> Bool {
        
        let size = (bodySize + 10)
        
        let yIndex = snakeHead.frame.origin.y / size
        let xIndex = snakeHead.frame.origin.x / size
        
        switch direction {
        case .up:
            return yIndex == frame.origin.y - size && xIndex == frame.origin.x
        case .down:
            return yIndex == frame.origin.y + size && xIndex == frame.origin.x
        case .left:
            return xIndex == frame.origin.x - size && yIndex == frame.origin.y
        case .right:
            return  xIndex == frame.origin.x + size && yIndex == frame.origin.y
        }
    }
    
    func printBody() {
//        Snake.reset()
//
//        let head = "Head { \(Snake.head!.description) index: \(Snake.index) of count: \(Snake.count - 1) }"
//        let body = "Body {@text}"
//
//        var text = ""
//
//        while let part = getNetPart() {
//            text += ", \(part.description) index: \(Snake.index) of count: \(Snake.count - 1) "
//        }
//
//        text = "//////////////////////////////////////////////////////////////////////////////////\n\(text.isEmpty ? head : "\(head) \(body.replacingOccurrences(of: "@text", with: text.dropFirst()))")\n"
//
//        print(text)
//
//        Snake.reset()
    }
    
    func getNetPart() -> SnakePart? {
        Snake.current = Snake.current?.prv
        Snake.index += 1
        
        return Snake.current
    }
}

internal class SnakePart: CustomStringConvertible {
    
    var locationFrame: CGRect
    var image: UIImageView?
    
    var prv: SnakePart?
    var next: SnakePart?
    
    var description: String {
        return printPart()
    }
    
    init(locationFrame: CGRect, image: UIImageView?) {
        self.locationFrame = locationFrame
        self.image = image
    }
    
    func updateFrame(frame: CGRect) {
        locationFrame = frame
    }
    
    func addBodyPart(part: SnakePart) {
        prv = part
        part.next = self
    }
    
    func printPart() -> String {
        let xFloat: CGFloat = (image!.frame.origin.x / image!.frame.size.width) + 1
        let yFloat: CGFloat = (image!.frame.origin.y  / image!.frame.size.height)
        
        let point = CGPoint(x: xFloat, y: yFloat)
        
        let originX = Int(point.x)
        let originY = Int(point.y)
        
        let key = "(\(originX), \(originY))"
        
        return "\(key)"
    }
}

class PointOnBoard {
    static func create(loc: CGPoint, size: CGFloat, image: UIImage = UIImage(named: "bodyPart")!) -> UIImageView {
        let bodyFrame = CGRect(x: loc.x, y: loc.y, width: size, height: size)
        
        let bodyImageView = UIImageView(frame: bodyFrame)
        
        let bodyImage = image
        
        bodyImageView.image = bodyImage
        
        bodyImageView.layer.cornerRadius = bodyImageView.frame.width / 2
        
        bodyImageView.clipsToBounds = true
        
        return bodyImageView
    }
    
    static func generateKeyPoint(origin: CGPoint) -> String {
        let originX = Int(origin.x)
        let originY = Int(origin.y)
        
        let key = "(\(originX), \(originY))"
        
        return key
    }
}

import AVFoundation

private class SoundManager {
    
    private static var player: AVAudioPlayer?
    
    static func stop() {
        player?.stop()
    }
    
    static func play() {
        player?.play()
    }
    
    static func playSound(named: String, numberOfLoops: Int = -1, volume: Float = 0.6) {
        guard let url = Bundle.main.url(forResource:named, withExtension: "mp3") else { return }
        
        do {
            stop()
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            
            player?.enableRate = true
            
            player?.volume = volume
            
            player?.numberOfLoops = numberOfLoops
            
            /* iOS 10 and earlier require the following line:
             player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
            
            guard let player = player else { return }
            
            player.play()
            
        } catch let error {
            print(error.localizedDescription)
        }
    }
}
