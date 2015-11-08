//
//  FirstViewController.m
//  classicFilms
//
//  Created by Stefan Arn on 11/10/15.
//  Copyright © 2015 Stefan Arn. All rights reserved.
//

#import "ARNMovieOverviewController.h"
#import "ARNArchiveController.h"
#import "ARNMovieController.h"
#import "ARNMoviePosterCell.h"
#import "ARNMovie.h"
#import "Movie.h"
#import "AppDelegate.h"
#import <AVKit/AVKit.h>

@interface ARNMovieOverviewController ()
    @property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
    @property(nonatomic, strong) UICollectionView *collectionView;
    @property(nonatomic, strong) UIActivityIndicatorView *refreshActivityIndicator;
    @property(nonatomic, strong) NSBlockOperation *blockOperation;
    @property(nonatomic, assign) BOOL shouldReloadCollectionView;
@end

@implementation ARNMovieOverviewController

- (id)init
{
    self = [super init];
    if(self)
    {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if(self)
    {
        [self setup];
    }
    return self;
}

// common setup method used be init's
- (void)setup
{
    _collectionType = [NSString string];
    _collectionTypeExlusion = [NSString string];
    _shouldReloadCollectionView = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // layout
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    [flowLayout setScrollDirection:UICollectionViewScrollDirectionVertical];
    [flowLayout setMinimumLineSpacing:0.0f];
    [flowLayout setMinimumInteritemSpacing:0.0f];
    
    // collection view
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:flowLayout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    
    // register custom cells
    [self.collectionView registerClass:[ARNMoviePosterCell class] forCellWithReuseIdentifier:@"ARNMoviePosterCell"];
    
    // add eveything to view hirarchy
    [self.view addSubview:self.collectionView];
    
    // activity indicator
    self.refreshActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.refreshActivityIndicator.frame = self.view.frame;
    self.refreshActivityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.refreshActivityIndicator];
    
    // set up the fetcher for the data
    [[self fetchedResultsController] performFetch:nil];
    
    // fetch the first few movies
    [[ARNArchiveController sharedInstance] fetchForCollection:self.collectionType withExclusion:self.collectionTypeExlusion andPageNumber:1 withRows:ARCHIVE_ORG_ROW_COUNT];
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if(_fetchedResultsController != nil)
    {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Movie"];
    
    // only fetch valid object for our collection
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:
                                                                                 [NSPredicate predicateWithFormat:@"collection == %@", self.collectionType],
                                                                                 [NSPredicate predicateWithFormat:@"tmdb_id.length > 0"],
                                                                                 [NSPredicate predicateWithFormat:@"title.length > 0"],
                                                                                 [NSPredicate predicateWithFormat:@"posterURL.length > 0"],
                                                                                 nil]];

    // sort by year
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"year" ascending:YES];
    fetchRequest.sortDescriptors = @[descriptor];
    
    // fetcher
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSManagedObjectContext *context = appDelegate.managedObjectContext;
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                                               managedObjectContext:context
                                                                                                 sectionNameKeyPath:nil
                                                                                                          cacheName:nil];
    
    self.fetchedResultsController = fetchedResultsController;
    _fetchedResultsController.delegate = self;
    
    return _fetchedResultsController;
}


#pragma mark -
#pragma mark UICollectionViewDataSource methods

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    id sectionInfo = [[_fetchedResultsController sections] objectAtIndex:section];
    NSUInteger numberOfItems = [sectionInfo numberOfObjects];
    if (numberOfItems > 0) {
        [self.refreshActivityIndicator stopAnimating];
    } else {
        [self.refreshActivityIndicator startAnimating];
    }
    return numberOfItems;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    // Setup cell identifier
    ARNMoviePosterCell *cell = (ARNMoviePosterCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"ARNMoviePosterCell" forIndexPath:indexPath];
    
    id obj = [_fetchedResultsController objectAtIndexPath:indexPath];
    if (obj != nil) {
        if ([obj isKindOfClass:[Movie class]]) {
            [cell configureCellWithMovie:[[ARNMovie alloc] initWithAttributesOfManagedObject:obj]];
        }
    }
    
    return cell;
}


#pragma mark -
#pragma mark UICollectionViewDelegate methods

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if (cell != nil && [cell isKindOfClass:[ARNMoviePosterCell class]]) {
        ARNMoviePosterCell *posterCell = (ARNMoviePosterCell *)cell;
        if (posterCell.arnMovie != nil) {
            [posterCell showActivityIndicator];
            [[ARNArchiveController sharedInstance] fetchSourceFileForMovie:posterCell.arnMovie andCompletionBlock:^(NSString *sourceFile) {
                [posterCell stopActivityIndicator];
                if ([sourceFile length] > 0) {
                    // open the stream
                    //https://archive.org/download/night_of_the_living_dead/night_of_the_living_dead_512kb.mp4
                    NSString *videoStream = [NSString stringWithFormat:@"%@%@/%@", @"https://archive.org/download/", posterCell.arnMovie.archive_id, sourceFile];
                    
                    NSURL *videoURL = [NSURL URLWithString:videoStream];
                    //AVPlayer *player = [AVPlayer playerWithURL:videoURL];
                    
                    AVPlayerViewController *playerViewController = [[AVPlayerViewController alloc] init];
                    playerViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
                    [self presentViewController:playerViewController animated:YES completion:nil];
                    
                    AVPlayer *player = [[AVPlayer alloc] initWithURL:videoURL];
                    player.closedCaptionDisplayEnabled = true;
                    
                    playerViewController.player = player;
                    [playerViewController.player play];
                    
//                    AVPlayerViewController *playerViewController = [AVPlayerViewController new];
//                    playerViewController.player = player;
//                    
//                    [self presentViewController:playerViewController animated:YES completion:^{
//                        [player play];
//                    }];
                }
            }];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didUpdateFocusInContext:(UICollectionViewFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    // the focus got changed, let's check which cell got focused and if we need to load more cells from the backend
    NSInteger focusedCellNumber = context.nextFocusedIndexPath.row + 1;
    NSInteger totalCellNumber = [collectionView numberOfItemsInSection:context.nextFocusedIndexPath.section];
    NSInteger distanceToLastCell = totalCellNumber - focusedCellNumber;
    
    if(distanceToLastCell < 24) {
        UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:context.nextFocusedIndexPath];
        if (cell != nil && [cell isKindOfClass:[ARNMoviePosterCell class]]) {
            ARNMoviePosterCell *posterCell = (ARNMoviePosterCell *)cell;
            if (posterCell.arnMovie != nil && [posterCell.arnMovie.page_number integerValue] >= 0) {
                // start a background fetch of new movies
                [[ARNArchiveController sharedInstance] fetchForCollection:self.collectionType withExclusion:self.collectionTypeExlusion andPageNumber:([posterCell.arnMovie.page_number integerValue] + 1) withRows:ARCHIVE_ORG_ROW_COUNT];
            }
        }
    }
}


#pragma mark -
#pragma mark UICollectionViewDelegateFlowLayout methods

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(80.0f, 80.0f, 80.0f, 80.0f);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 30.0f;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 20.0f;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(256, 464);
}


#pragma mark -
#pragma mark NSFetchedResultsControllerDelegate methods

// implementation is based on gist: https://gist.github.com/iwasrobbed/5528897
- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    self.shouldReloadCollectionView = NO;
    self.blockOperation = [[NSBlockOperation alloc] init];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    __weak UICollectionView *collectionView = self.collectionView;
    switch (type) {
        case NSFetchedResultsChangeInsert: {
            [self.blockOperation addExecutionBlock:^{
                [collectionView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]];
            }];
            break;
        }
            
        case NSFetchedResultsChangeDelete: {
            [self.blockOperation addExecutionBlock:^{
                [collectionView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]];
            }];
            break;
        }
            
        case NSFetchedResultsChangeUpdate: {
            [self.blockOperation addExecutionBlock:^{
                [collectionView reloadSections:[NSIndexSet indexSetWithIndex:sectionIndex]];
            }];
            break;
        }
            
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    __weak UICollectionView *collectionView = self.collectionView;
    switch (type) {
        case NSFetchedResultsChangeInsert: {
            if ([self.collectionView numberOfSections] > 0) {
                if ([self.collectionView numberOfItemsInSection:indexPath.section] == 0) {
                    self.shouldReloadCollectionView = YES;
                } else {
                    [self.blockOperation addExecutionBlock:^{
                        [collectionView insertItemsAtIndexPaths:@[newIndexPath]];
                    }];
                }
            } else {
                self.shouldReloadCollectionView = YES;
            }
            break;
        }
            
        case NSFetchedResultsChangeDelete: {
            if ([self.collectionView numberOfItemsInSection:indexPath.section] == 1) {
                self.shouldReloadCollectionView = YES;
            } else {
                [self.blockOperation addExecutionBlock:^{
                    [collectionView deleteItemsAtIndexPaths:@[indexPath]];
                }];
            }
            break;
        }
            
        case NSFetchedResultsChangeUpdate: {
            [self.blockOperation addExecutionBlock:^{
                [collectionView reloadItemsAtIndexPaths:@[indexPath]];
            }];
            break;
        }
            
        case NSFetchedResultsChangeMove: {
            [self.blockOperation addExecutionBlock:^{
                [collectionView moveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
            }];
            break;
        }
            
        default:
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // Checks if we should reload the collection view to fix a bug @ http://openradar.appspot.com/12954582
    if (self.shouldReloadCollectionView) {
        [self.collectionView reloadData];
    } else {
        [self.collectionView performBatchUpdates:^{
            [self.blockOperation start];
        } completion:nil];
    }
}

- (void)dealloc {
    _fetchedResultsController.delegate = nil;
}

@end
