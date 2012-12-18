//
//  AlbumViewController.m
//  AlbumArt
//
//  Created by Jim Kubicek on 12/13/12.
//  Copyright (c) 2012 Jim Kubicek. All rights reserved.
//

#import "AlbumViewController.h"
#import "SLColorArt.h"
#import <MediaPlayer/MediaPlayer.h>

@interface AlbumViewController ()

@property (strong) NSArray *albums;

@end

@implementation AlbumViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    MPMediaQuery *query = [[MPMediaQuery alloc] init];
    [query setGroupingType: MPMediaGroupingAlbum];

    NSArray *albums = [query collections];
    self.albums = albums;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.albums count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"albumCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    MPMediaItem *representativeItem = [[self.albums objectAtIndex:indexPath.row ] representativeItem];
    NSString *artistName = [representativeItem valueForProperty: MPMediaItemPropertyArtist];
    NSString *albumName = [representativeItem valueForProperty: MPMediaItemPropertyAlbumTitle];

    cell.textLabel.text = artistName;
    cell.detailTextLabel.text = albumName;

    MPMediaItemArtwork *artwork = [representativeItem valueForProperty: MPMediaItemPropertyArtwork];

    NSDate *startTime = [NSDate date];

    CGSize artSize = CGSizeMake(100.f, 100.f);
    UIImage *artworkImage = [artwork imageWithSize:artSize];
    SLColorArt *colorArt = [[SLColorArt alloc] initWithImage:artworkImage scaledSize:artSize];

    NSDate *endTime = [NSDate date];
    NSTimeInterval time = [endTime timeIntervalSinceDate:startTime];
    NSLog(@"Time to create SLColorArt: %f", time);

    cell.imageView.image = colorArt.scaledImage;
    cell.contentView.backgroundColor = colorArt.backgroundColor;

    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = colorArt.primaryColor;

    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.textColor = colorArt.secondaryColor;

    return cell;
}

@end
